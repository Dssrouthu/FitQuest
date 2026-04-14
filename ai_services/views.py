from rest_framework import viewsets, permissions, mixins, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import PoseAnalysis, RecoveryScore, AICoachMessage
from .serializers import PoseAnalysisSerializer, RecoveryScoreSerializer, AICoachMessageSerializer
from workouts.models import WorkoutPlan, WorkoutExercise, Exercise


class PoseAnalysisViewSet(viewsets.ModelViewSet):
    serializer_class = PoseAnalysisSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return PoseAnalysis.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class RecoveryScoreViewSet(viewsets.ModelViewSet):
    serializer_class = RecoveryScoreSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return RecoveryScore.objects.filter(user=self.request.user)


class AICoachMessageViewSet(mixins.ListModelMixin,
                             mixins.UpdateModelMixin,
                             viewsets.GenericViewSet):
    serializer_class = AICoachMessageSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return AICoachMessage.objects.filter(user=self.request.user)

    @action(detail=True, methods=['post'])
    def accept_suggestion(self, request, pk=None):
        message = self.get_object()
        if not message.suggested_exercise_name or message.suggestion_accepted:
            return Response({'error': 'No active suggestion found'}, status=status.HTTP_400_BAD_REQUEST)
        
        # 1. Find the exercise in the database
        try:
            exercise = Exercise.objects.get(name__iexact=message.suggested_exercise_name)
        except Exercise.DoesNotExist:
            return Response({'error': f'Exercise "{message.suggested_exercise_name}" not found in database'}, status=status.HTTP_404_NOT_FOUND)

        # 2. Find user's active plan
        plan = WorkoutPlan.objects.filter(assigned_to=request.user).first()
        if not plan:
            return Response({'error': 'No active workout plan found to add exercise to'}, status=status.HTTP_404_NOT_FOUND)

        # 3. Add exercise to plan
        WorkoutExercise.objects.get_or_create(
            plan=plan,
            exercise=exercise,
            defaults={'sets': 3, 'reps': '12-15', 'day_label': 'Any'}
        )

        # 4. Mark accepted
        message.suggestion_accepted = True
        message.save()

        return Response({'success': f'"{exercise.name}" added to your plan: {plan.name}'})
