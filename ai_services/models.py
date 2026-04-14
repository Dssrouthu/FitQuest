from django.db import models
from django.conf import settings  # ✅ FIXED IMPORT

class PoseAnalysis(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE) # ✅ FIXED RELATION
    exercise_name = models.CharField(max_length=100)
    reps_count = models.IntegerField(default=0)
    accuracy_score = models.FloatField(default=0.0)
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - {self.exercise_name}"

class RecoveryScore(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE) # ✅ FIXED RELATION
    score = models.IntegerField(default=100)
    recommendation = models.TextField()
    date = models.DateField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - Score: {self.score}"

class StrengthPrediction(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE) # ✅ FIXED RELATION
    exercise = models.CharField(max_length=100)
    predicted_1rm = models.FloatField()  # 1 Rep Max
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - {self.exercise}: {self.predicted_1rm}kg"

class VoiceCommand(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE) # ✅ FIXED RELATION
    command_text = models.CharField(max_length=255)
    processed_action = models.CharField(max_length=100, null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - {self.command_text}"


class AICoachMessage(models.Model):
    INTERVENTION_CHOICES = [
        ('recovery', 'Recovery Intervation'),
        ('progressive_overload', 'Progressive Overload Tips'),
        ('consistency', 'Consistency Check'),
        ('milestone', 'Milestone Celebration'),
        ('form_correction', 'Form Correction Tip'),
        ('injury_prevention', 'Injury Prevention Warning'),
    ]
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='ai_coach_messages')
    message = models.TextField()
    intervention_type = models.CharField(max_length=50, choices=INTERVENTION_CHOICES)
    is_read = models.BooleanField(default=False)
    
    # Actionable suggestions (rule-based AI Coach)
    suggested_exercise_name = models.CharField(max_length=100, null=True, blank=True)
    suggestion_accepted = models.BooleanField(default=False)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"AI Coach to {self.user.username}: {self.message[:30]}..."
