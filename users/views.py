from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.authtoken.models import Token
from django.contrib.auth import authenticate
from .models import CustomUser, CoachAccessKey, AssessmentForm
from .serializers import UserSerializer, RegisterSerializer, LoginSerializer
from workouts.models import WorkoutPlan
from nutrition.models import DietPlan
from quests.models import Quest, QuestCompletion
from shop.models import Purchase

class RegisterView(generics.CreateAPIView):
    queryset = CustomUser.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]

class LoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if serializer.is_valid():
            username = serializer.validated_data['username']
            password = serializer.validated_data['password']
            user = authenticate(username=username, password=password)

            if user:
                token, _ = Token.objects.get_or_create(user=user)
                return Response({
                    "token": token.key,
                    "role": user.role,
                    "user": UserSerializer(user).data,
                    "message": "Login Successful"
                })
            return Response({"error": "Invalid Credentials"}, status=status.HTTP_401_UNAUTHORIZED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class GenerateCoachKeyView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        caller_role = request.user.role
        if caller_role not in ('HIGH_COUNCIL', 'SUPER_COACH'):
            return Response({'error': 'Forbidden'}, status=403)

        # Admins (HIGH_COUNCIL) generate SUPER_COACH keys by default.
        # Super coaches generate COACH keys.
        # Caller can also pass key_type explicitly.
        requested_type = request.data.get('key_type')
        if requested_type in ('COACH', 'SUPER_COACH'):
            key_type = requested_type
        elif caller_role == 'HIGH_COUNCIL':
            key_type = 'SUPER_COACH'
        else:
            key_type = 'COACH'

        new_key = CoachAccessKey.generate_key()
        CoachAccessKey.objects.create(key=new_key, key_type=key_type)
        return Response({"key": new_key, "key_type": key_type}, status=status.HTTP_201_CREATED)

class UserListView(generics.ListAPIView):
    queryset = CustomUser.objects.all()
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAdminUser]


# ... (Keep existing imports and views: Register, Login, GenerateKey, UserList)

# 5. Coach Roster View (Get My Recruits)
class CoachRosterView(generics.ListAPIView):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Only return users where coach = Current Logged In User
        return CustomUser.objects.filter(coach=self.request.user)


# 6. Assign Coach View (Super Coach or High Council)
class AssignCoachView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        if request.user.role not in ('SUPER_COACH', 'HIGH_COUNCIL'):
            return Response({'error': 'Forbidden'}, status=403)

        recruit_id = request.data.get('recruit_id')
        coach_id = request.data.get('coach_id')

        try:
            recruit = CustomUser.objects.get(id=recruit_id, role='RECRUIT')
            coach = CustomUser.objects.get(id=coach_id, role='GUILD_MASTER')

            recruit.coach = coach
            recruit.is_new_assignment = True
            recruit.save()

            # If assigning as Super Coach, also set coach's supervisor
            if request.user.role == 'SUPER_COACH':
                coach.super_coach = request.user
                coach.save()

            return Response({"message": f"Assigned {recruit.username} to {coach.username}"})
        except CustomUser.DoesNotExist:
            return Response({"error": "User not found"}, status=404)

# ... existing imports

class AcknowledgeRecruitView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        recruit_id = request.data.get('recruit_id')
        try:
            # Ensure this recruit actually belongs to the logged-in Coach
            recruit = CustomUser.objects.get(id=recruit_id, coach=request.user)
            recruit.is_new_assignment = False
            recruit.save()
            return Response({"message": "Recruit acknowledged"})
        except CustomUser.DoesNotExist:
            return Response({"error": "Recruit not found or not yours"}, status=404)


class CoachSummaryView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        return Response({
            'athlete_count':          user.recruits.count(),
            'new_athlete_count':      user.recruits.filter(is_new_assignment=True).count(),
            'plan_count':             WorkoutPlan.objects.filter(coach=user).count(),
            'diet_plan_count':        DietPlan.objects.filter(coach=user).count(),
            'quest_count':            Quest.objects.filter(coach=user).count(),
            'completed_quest_count':  QuestCompletion.objects.filter(quest__coach=user).count(),
            'pending_purchase_count': Purchase.objects.filter(item__coach=user, is_fulfilled=False).count(),
        })


class AthleteAnalyticsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, recruit_id):
        try:
            recruit = CustomUser.objects.get(id=recruit_id, coach=request.user)
        except CustomUser.DoesNotExist:
            return Response({'error': 'Not found'}, status=404)

        completions = QuestCompletion.objects.filter(recruit=recruit).select_related('quest')
        return Response({
            'xp':                 recruit.xp,
            'level':              recruit.level,
            'coins':              recruit.coin_balance,
            'workout_plans':      recruit.assigned_plans.count(),
            'diet_plans':         recruit.assigned_diet_plans.count(),
            'quests_completed':   completions.count(),
            'total_xp_earned':    sum(c.quest.xp_reward for c in completions),
            'total_coins_earned': sum(c.quest.coin_reward for c in completions),
            'recent_quests': [
                {'name': c.quest.name, 'xp': c.quest.xp_reward, 'coins': c.quest.coin_reward}
                for c in completions.order_by('-completed_at')[:5]
            ],
        })


class LeaderboardView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role == 'GUILD_MASTER':
            qs = CustomUser.objects.filter(coach=user).select_related('coach')
        else:
            qs = CustomUser.objects.filter(coach=user.coach).select_related('coach') if user.coach else CustomUser.objects.none()
        return Response(UserSerializer(qs.order_by('-level', '-xp'), many=True).data)


class MyCoachView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        if request.user.coach:
            return Response(UserSerializer(request.user.coach).data)
        return Response({'error': 'No coach assigned'}, status=404)


class AssessmentCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        # Only recruits fill out assessment forms
        data = request.data.copy()
        
        player_class = data.get('player_class')
        if player_class:
            request.user.player_class = player_class
            request.user.save()

        AssessmentForm.objects.update_or_create(
            user=request.user,
            defaults={
                'waist_circumference': float(data.get('waist_circumference', 0)),
                'bicep_size': float(data.get('bicep_size', 0)) if data.get('bicep_size') else None,
                'chest_size': float(data.get('chest_size', 0)) if data.get('chest_size') else None,
                'thigh_size': float(data.get('thigh_size', 0)) if data.get('thigh_size') else None,
                'medical_history': data.get('medical_history', ''),
                'injuries': data.get('injuries', ''),
                'food_preference': data.get('food_preference', 'Non-Veg'),
                'meals_per_day': int(data.get('meals_per_day', 3)),
                'typical_breakfast': data.get('typical_breakfast', ''),
                'typical_lunch': data.get('typical_lunch', ''),
                'typical_dinner': data.get('typical_dinner', ''),
                'typical_snacks': data.get('typical_snacks', ''),
                'tea_coffee_cups': data.get('tea_coffee_cups', ''),
                'alcohol_frequency': data.get('alcohol_frequency', ''),
                'food_allergies': data.get('food_allergies', ''),
                'exercise_experience': data.get('exercise_experience', ''),
                'preferred_exercise': data.get('preferred_exercise', ''),
                'days_available': data.get('days_available', ''),
            }
        )
        return Response({'message': 'Assessment saved'}, status=201)


# --- NEW VIEWS (Phase 4) ---

class UpdateProfileView(APIView):
    """PATCH /api/users/profile/ — update own profile fields."""
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request):
        user = request.user
        allowed = ('weight', 'height', 'goal', 'activity_level', 'age', 'gender')
        for field in allowed:
            if field in request.data:
                val = request.data[field]
                if field in ('weight', 'height'):
                    try:
                        val = float(val)
                    except (ValueError, TypeError):
                        return Response({'error': f'Invalid value for {field}'}, status=400)
                setattr(user, field, val)
        user.save()
        return Response(UserSerializer(user).data)


class SuperCoachRosterView(generics.ListAPIView):
    """GET /api/users/my-coaches/ — list coaches managed by the current super coach."""
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        if self.request.user.role not in ('SUPER_COACH', 'HIGH_COUNCIL'):
            return CustomUser.objects.none()
        return CustomUser.objects.filter(super_coach=self.request.user)


class SuperCoachAthleteListView(generics.ListAPIView):
    """GET /api/users/coach/<coach_id>/athletes/ — athletes of a specific coach under super coach."""
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        coach_id = self.kwargs['coach_id']
        user = self.request.user
        if user.role not in ('SUPER_COACH', 'HIGH_COUNCIL'):
            return CustomUser.objects.none()
        try:
            coach = CustomUser.objects.get(id=coach_id, role='GUILD_MASTER', super_coach=user)
        except CustomUser.DoesNotExist:
            return CustomUser.objects.none()
        return CustomUser.objects.filter(coach=coach)


class DeleteUserView(APIView):
    """DELETE /api/users/<user_id>/delete/ — admin only."""
    permission_classes = [permissions.IsAdminUser]

    def delete(self, request, user_id):
        try:
            user = CustomUser.objects.get(id=user_id)
            if user == request.user:
                return Response({'error': 'Cannot delete yourself'}, status=400)
            user.delete()
            return Response({'message': 'User deleted'}, status=204)
        except CustomUser.DoesNotExist:
            return Response({'error': 'User not found'}, status=404)


# --- Phase 7: Super Coach "All" views ---

class SCAllAthletesView(APIView):
    """GET /api/users/sc-all-athletes/ — Returns ALL RECRUIT users."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        if request.user.role not in ('SUPER_COACH', 'HIGH_COUNCIL'):
            return Response({'error': 'Forbidden'}, status=403)
        athletes = CustomUser.objects.filter(role='RECRUIT').select_related('coach')
        data = [
            {
                'id': u.id,
                'username': u.username,
                'level': u.level,
                'goal': u.goal,
                'coach_name': u.coach.username if u.coach else None,
                'coach_id': u.coach.id if u.coach else None,
            }
            for u in athletes
        ]
        return Response(data)


class SCAllCoachesView(APIView):
    """GET /api/users/sc-all-coaches/ — Returns ALL GUILD_MASTER users."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        if request.user.role not in ('SUPER_COACH', 'HIGH_COUNCIL'):
            return Response({'error': 'Forbidden'}, status=403)
        coaches = CustomUser.objects.filter(role='GUILD_MASTER').select_related('super_coach')
        data = [
            {
                'id': u.id,
                'username': u.username,
                'level': u.level,
                'super_coach_name': u.super_coach.username if u.super_coach else None,
                'super_coach_id': u.super_coach.id if u.super_coach else None,
            }
            for u in coaches
        ]
        return Response(data)


class SCClaimCoachView(APIView):
    """POST /api/users/sc-claim-coach/<coach_id>/ — Set coach.super_coach = request.user"""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, coach_id):
        if request.user.role not in ('SUPER_COACH', 'HIGH_COUNCIL'):
            return Response({'error': 'Forbidden'}, status=403)
        try:
            coach = CustomUser.objects.get(id=coach_id, role='GUILD_MASTER')
            coach.super_coach = request.user
            coach.save()
            return Response({'message': f'Coach {coach.username} now under your management'})
        except CustomUser.DoesNotExist:
            return Response({'error': 'Coach not found'}, status=404)


class SCClaimAthleteView(APIView):
    """POST /api/users/sc-claim-athlete/<athlete_id>/ — Set athlete.coach = request.user"""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, athlete_id):
        if request.user.role not in ('SUPER_COACH', 'HIGH_COUNCIL'):
            return Response({'error': 'Forbidden'}, status=403)
        try:
            athlete = CustomUser.objects.get(id=athlete_id, role='RECRUIT')
            athlete.coach = request.user
            athlete.save()
            return Response({'message': f'Athlete {athlete.username} assigned to you'})
        except CustomUser.DoesNotExist:
            return Response({'error': 'Athlete not found'}, status=404)