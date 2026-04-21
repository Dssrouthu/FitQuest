from django.http import Http404
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import Exercise, WorkoutPlan, WorkoutExercise
from .serializers import ExerciseSerializer, WorkoutPlanSerializer
from quests.models import Quest

# 1. List all Exercises (DISABLE PAGINATION so App gets all 150+)
class ExerciseListView(generics.ListAPIView):
    queryset = Exercise.objects.all()
    serializer_class = ExerciseSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None

# 2. Create a Workout Plan
class CreateWorkoutView(generics.CreateAPIView):
    queryset = WorkoutPlan.objects.all()
    serializer_class = WorkoutPlanSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        user = self.request.user
        if user.role == 'RECRUIT':
            plan = serializer.save(coach=None)
            plan.assigned_to.add(user)

            # Auto-schedule for recruits: every day of the week
            from .models import WorkoutExercise, Exercise
            days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
            
            # Try to get some common exercises
            default_exs = list(Exercise.objects.all()[:3])
            if default_exs:
                for i, day in enumerate(days):
                    # Rotate between the exercises
                    ex = default_exs[i % len(default_exs)]
                    WorkoutExercise.objects.create(
                        plan=plan,
                        exercise=ex,
                        day_label=day,
                        order=1,
                        sets=3,
                        reps=10
                    )
        else:
            serializer.save(coach=user)

# 3. Assign Plan
class AssignPlanView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        plan_id = request.data.get('plan_id')
        recruit_ids = request.data.get('recruit_ids')
        xp_reward = int(request.data.get('xp_reward', 100))
        coin_reward = int(request.data.get('coin_reward', 10))
        auto_quest = request.data.get('auto_quest', True)

        try:
            plan = WorkoutPlan.objects.get(id=plan_id, coach=request.user)
            if isinstance(recruit_ids, list):
                plan.assigned_to.add(*recruit_ids)
            else:
                plan.assigned_to.add(recruit_ids)

            quest_id = None
            if auto_quest:
                quest = Quest.objects.create(
                    coach=request.user,
                    title=f"Complete: {plan.name}",
                    description=f"Finish your assigned training plan '{plan.name}'",
                    xp_reward=xp_reward,
                    coin_reward=coin_reward,
                    difficulty='MEDIUM',
                    is_auto_generated=True,
                )
                ids = recruit_ids if isinstance(recruit_ids, list) else [recruit_ids]
                quest.assigned_to.add(*ids)
                quest_id = quest.id

            return Response({"message": "Plan assigned successfully", "quest_id": quest_id})
        except WorkoutPlan.DoesNotExist:
            return Response({"error": "Plan not found or not yours"}, status=404)

# 4. Get Coach's Plans (DISABLE PAGINATION so App gets the list)
class CoachPlansView(generics.ListAPIView):
    serializer_class = WorkoutPlanSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        return WorkoutPlan.objects.filter(coach=self.request.user).order_by('-created_at')


# 5. Update / Delete a specific plan
class UpdateDeleteWorkoutPlanView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self, pk, user):
        try:
            if user.role == 'RECRUIT':
                return WorkoutPlan.objects.get(id=pk, coach__isnull=True, assigned_to=user)
            return WorkoutPlan.objects.get(id=pk, coach=user)
        except WorkoutPlan.DoesNotExist:
            raise Http404

    def put(self, request, pk):
        plan = self.get_object(pk, request.user)
        plan.name        = request.data.get('name', plan.name)
        plan.description = request.data.get('description', plan.description)
        plan.day_names   = request.data.get('day_names', plan.day_names)
        plan.save()
        # Full-replace exercises
        exercises_data = request.data.get('workout_exercises', [])
        plan.workout_exercises.all().delete()
        for i, ex in enumerate(exercises_data):
            WorkoutExercise.objects.create(
                plan=plan,
                exercise_id=ex['exercise_id'],
                sets=ex.get('sets', 3),
                reps=ex.get('reps', '10-12'),
                rest_time=ex.get('rest_time', 60),
                order=i + 1,
                day_label=ex.get('day_label', 'Any'),
            )
        return Response(WorkoutPlanSerializer(plan).data)

    def delete(self, request, pk):
        self.get_object(pk, request.user).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


# 6. Recruit: Assigned Plans
class RecruitAssignedPlansView(generics.ListAPIView):
    serializer_class = WorkoutPlanSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        return self.request.user.assigned_plans.prefetch_related(
            'workout_exercises__exercise').all()


# 7. Athlete: Own Self-Created Plans
class AthleteOwnPlansView(generics.ListAPIView):
    serializer_class = WorkoutPlanSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        return WorkoutPlan.objects.filter(
            coach__isnull=True, assigned_to=self.request.user
        ).prefetch_related('workout_exercises__exercise')
