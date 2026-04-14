from datetime import date

from rest_framework import generics, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from .models import Quest, QuestCompletion, DailyQuestCompletion, Guild, CoOpQuest
from .serializers import QuestSerializer, QuestCompletionSerializer, AssignedQuestSerializer
from users.models import CustomUser


# ── Recruit: Guild Hub (View their guild and active quests) ──────────────────
class GuildQuestView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        guilds = request.user.guilds.all()
        if not guilds.exists():
            return Response({'has_guild': False})

        guild = guilds.first() # Assume one guild for now
        active_quests = CoOpQuest.objects.filter(
            guild=guild,
            deadline__gt=timezone.now(),
            is_completed=False
        ).order_by('deadline')

        quests_data = []
        for q in active_quests:
            quests_data.append({
                'id': q.id,
                'title': q.title,
                'description': q.description,
                'target_metric': q.target_metric,
                'target_value': q.target_value,
                'current_progress': q.current_progress,
                'deadline': str(q.deadline),
                'progress_percent': min(100, (q.current_progress / q.target_value) * 100) if q.target_value > 0 else 0
            })

        return Response({
            'has_guild': True,
            'guild_name': guild.name,
            'guild_description': guild.description,
            'active_quests': quests_data
        })


# ── Coach: list all their quests ─────────────────────────────────────────────
class CoachQuestListView(generics.ListAPIView):
    serializer_class   = QuestSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class   = None

    def get_queryset(self):
        return Quest.objects.filter(coach=self.request.user).order_by('-created_at')


# ── Coach: create a new quest ─────────────────────────────────────────────────
class CreateQuestView(generics.CreateAPIView):
    serializer_class   = QuestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(coach=self.request.user)


# ── Coach: delete a quest ─────────────────────────────────────────────────────
class DeleteQuestView(generics.DestroyAPIView):
    serializer_class   = QuestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Quest.objects.filter(coach=self.request.user)


# ── Coach: assign quest to one or more recruits ───────────────────────────────
class AssignQuestView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        quest_id     = request.data.get('quest_id')
        recruit_ids  = request.data.get('recruit_ids', [])
        is_community = request.data.get('is_community', False)

        try:
            quest = Quest.objects.get(id=quest_id, coach=request.user)
        except Quest.DoesNotExist:
            return Response({'error': 'Quest not found'}, status=status.HTTP_404_NOT_FOUND)

        if is_community:
            recruits = request.user.recruits.filter(role='RECRUIT')
        else:
            recruits = CustomUser.objects.filter(id__in=recruit_ids, role='RECRUIT')

        quest.assigned_to.set(recruits)
        quest.is_community = is_community
        quest.save()
        return Response({'message': f'Assigned to {recruits.count()} athlete(s)'})


# ── Recruit: view their assigned quests ───────────────────────────────────────
class MyQuestsView(generics.ListAPIView):
    serializer_class   = AssignedQuestSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class   = None

    def get_queryset(self):
        return self.request.user.assigned_quests.all().order_by('-created_at')

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx['request'] = self.request
        return ctx


# ── Recruit: complete a quest (awards XP + coins) ────────────────────────────
class CompleteQuestView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        quest_id = request.data.get('quest_id')

        try:
            quest = Quest.objects.get(id=quest_id)
        except Quest.DoesNotExist:
            return Response({'error': 'Quest not found'}, status=status.HTTP_404_NOT_FOUND)

        # Verify quest is assigned to this recruit
        if not quest.assigned_to.filter(id=request.user.id).exists():
            return Response({'error': 'Not assigned to this quest'}, status=status.HTTP_403_FORBIDDEN)

        completion, created = QuestCompletion.objects.get_or_create(
            recruit=request.user, quest=quest)

        if not created:
            return Response({'error': 'Quest already completed'}, status=status.HTTP_400_BAD_REQUEST)

        # Award XP and coins
        recruit = request.user
        recruit.xp    += quest.xp_reward
        recruit.coin_balance += quest.coin_reward

        # Simple level-up: every 500 XP = 1 level
        recruit.level = max(1, recruit.xp // 500 + 1)
        recruit.save()

        return Response({
            'message':     f'Quest complete! +{quest.xp_reward} XP, +{quest.coin_reward} coins',
            'new_xp':      recruit.xp,
            'new_coins':   recruit.coin_balance,
            'new_level':   recruit.level,
            'xp_reward':   quest.xp_reward,
            'coin_reward': quest.coin_reward,
        })


# ── Recruit: today's daily quests from assigned plans ────────────────────────
class TodayQuestsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        today = date.today()
        today_day = today.strftime('%A')  # e.g., 'Monday'

        missions = []

        # Workout missions: plans with exercises scheduled for today
        from workouts.models import WorkoutPlan
        assigned_plans = WorkoutPlan.objects.filter(
            assigned_to=user
        ).prefetch_related('workout_exercises__exercise')

        completed_ids = set(
            DailyQuestCompletion.objects.filter(
                user=user, source_type='workout', date=today
            ).values_list('source_id', flat=True)
        )
        nutrition_completed_ids = set(
            DailyQuestCompletion.objects.filter(
                user=user, source_type='nutrition', date=today
            ).values_list('source_id', flat=True)
        )

        for plan in assigned_plans:
            today_exercises = [
                we for we in plan.workout_exercises.all()
                if we.day_label == today_day
            ]
            if today_exercises:
                exercise_names = ', '.join(
                    set(we.exercise.name for we in today_exercises)
                )
                missions.append({
                    'type': 'workout',
                    'source_id': plan.id,
                    'title': f'{plan.name} — {today_day}',
                    'description': f'{len(today_exercises)} exercises: {exercise_names}',
                    'xp_reward': 100,
                    'coin_reward': 10,
                    'is_completed': plan.id in completed_ids,
                })

        # Nutrition mission: diet schedule for today
        from nutrition.models import DietSchedule
        try:
            schedule = DietSchedule.objects.get(recruit=user, day_of_week=today_day)
            if schedule.diet_plan:
                dp = schedule.diet_plan
                missions.append({
                    'type': 'nutrition',
                    'source_id': dp.id,
                    'title': f'Follow {dp.name}',
                    'description': f'Follow your nutrition plan for {today_day}',
                    'xp_reward': 50,
                    'coin_reward': 5,
                    'is_completed': dp.id in nutrition_completed_ids,
                })
        except DietSchedule.DoesNotExist:
            pass

        return Response(missions)


# ── Recruit: complete a daily quest ──────────────────────────────────────────
class CompleteDailyQuestView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        source_type = request.data.get('source_type')
        source_id = request.data.get('source_id')

        if source_type not in ('workout', 'nutrition') or source_id is None:
            return Response({'error': 'source_type and source_id required'},
                            status=status.HTTP_400_BAD_REQUEST)

        today = date.today()
        try:
            completion, created = DailyQuestCompletion.objects.get_or_create(
                user=request.user,
                source_type=source_type,
                source_id=int(source_id),
                date=today,
            )
        except Exception:
            return Response({'error': 'Already completed today'}, status=400)

        if not created:
            return Response({'error': 'Already completed today'}, status=400)

        # Award XP + coins
        xp_reward = 100 if source_type == 'workout' else 50
        coin_reward = 10 if source_type == 'workout' else 5

        recruit = request.user
        recruit.xp += xp_reward
        recruit.coin_balance += coin_reward
        recruit.level = max(1, recruit.xp // 500 + 1)
        recruit.save()

        return Response({
            'message': f'+{xp_reward} XP, +{coin_reward} coins',
            'new_xp': recruit.xp,
            'new_coins': recruit.coin_balance,
            'new_level': recruit.level,
            'xp_reward': xp_reward,
            'coin_reward': coin_reward,
        })
