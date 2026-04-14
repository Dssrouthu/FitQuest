from rest_framework import serializers
from .models import PoseAnalysis, RecoveryScore, StrengthPrediction, VoiceCommand, AICoachMessage

class PoseAnalysisSerializer(serializers.ModelSerializer):
    class Meta:
        model = PoseAnalysis
        fields = '__all__'

class RecoveryScoreSerializer(serializers.ModelSerializer):
    class Meta:
        model = RecoveryScore
        fields = '__all__'

class AICoachMessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = AICoachMessage
        fields = ['id', 'message', 'intervention_type', 'is_read', 'created_at', 'suggested_exercise_name', 'suggestion_accepted']
        read_only_fields = ['id', 'intervention_type', 'created_at', 'suggested_exercise_name']
