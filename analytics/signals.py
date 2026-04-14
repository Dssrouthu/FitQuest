from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import WorkoutSetLog
from ai_services.models import AICoachMessage
from workouts.models import WorkoutExercise, WorkoutPlan, Exercise
from django.utils import timezone
import datetime

@receiver(post_save, sender=WorkoutSetLog)
def check_for_ai_coaching_intervention(sender, instance, created, **kwargs):
    if not created:
        return
    
    user = instance.user
    today_start = timezone.now().replace(hour=0, minute=0, second=0, microsecond=0)

    # 1. FORM CORRECTION (Rule-Based)
    if instance.mistakes:
        mistakes_list = instance.mistakes.split(',')
        for mistake in mistakes_list:
            already_sent = AICoachMessage.objects.filter(
                user=user, 
                intervention_type='form_correction',
                message__contains=mistake,
                created_at__gte=today_start
            ).exists()

            if not already_sent:
                msg = ""
                suggested_ex = None
                if mistake == 'KNEES_CAVING':
                    msg = f"I noticed your knees caving during {instance.exercise_name}. This often means weak hip abductors. I suggest adding Glute Bridges to your routine to fix this."
                    suggested_ex = "Glute Bridge"
                elif mistake == 'HIPS_SAGGING':
                    msg = f"Your hips were sagging during {instance.exercise_name}. Core stability is key here. Would you like to add Planks to your next session?"
                    suggested_ex = "Plank"
                
                if msg:
                    AICoachMessage.objects.create(
                        user=user,
                        message=msg,
                        intervention_type='form_correction',
                        suggested_exercise_name=suggested_ex
                    )

    # 1.5 KINEMATIC FINGERPRINTING (Longitudinal Injury Prediction)
    # Check last 5 sets of same exercise for persistent mistakes
    last_5_sets = WorkoutSetLog.objects.filter(
        user=user, 
        exercise_name=instance.exercise_name
    ).order_by('-logged_at')[:5]

    if last_5_sets.count() >= 5:
        # Count occurrences of the same mistake in last 5 sets
        mistake_counts = {}
        for s in last_5_sets:
            if s.mistakes:
                for m in s.mistakes.split(','):
                    mistake_counts[m] = mistake_counts.get(m, 0) + 1
        
        for mistake, count in mistake_counts.items():
            if count >= 4: # Mistake present in 80% of recent sets
                already_sent_warning = AICoachMessage.objects.filter(
                    user=user,
                    intervention_type='injury_prevention',
                    message__contains=mistake,
                    created_at__gte=today_start - datetime.timedelta(days=3)
                ).exists()

                if not already_sent_warning:
                    warning_msg = f"Kinematic Warning: I've detected a persistent pattern of '{mistake}' in your last {count} sets of {instance.exercise_name}. This asymmetry often leads to joint inflammation. I've scheduled a mandatory deload and mobility session for this muscle group to prevent injury."
                    AICoachMessage.objects.create(
                        user=user,
                        message=warning_msg,
                        intervention_type='injury_prevention'
                    )

    # 2. PROGRESSIVE OVERLOAD / RECOVERY
    # Get last 3 sets for this user
    recent_logs = WorkoutSetLog.objects.filter(user=user).order_by('-logged_at')[:3]
    if recent_logs.count() < 3:
        return
    
    # RECOVERY Intervention
    all_too_hard = all(log.effectiveness == 'Too Hard' for log in recent_logs)
    if all_too_hard:
        already_sent = AICoachMessage.objects.filter(
            user=user, 
            intervention_type='recovery', 
            created_at__gte=today_start
        ).exists()
        
        if not already_sent:
            AICoachMessage.objects.create(
                user=user,
                message="Proactive Recovery: You've rated your last 3 sets as 'Too Hard'. I've adjusted tomorrow's volume to help you recover.",
                intervention_type='recovery'
            )
            # PROACTIVE ADJUSTMENT: Reduce sets by 1 for tomorrow's exercises
            tomorrow = (datetime.date.today() + datetime.timedelta(days=1)).strftime('%A')
            assigned_plans = user.assigned_plans.all()
            tomorrow_exercises = WorkoutExercise.objects.filter(
                plan__in=assigned_plans,
                day_label=tomorrow
            )
            for we in tomorrow_exercises:
                if we.sets > 1:
                    we.sets -= 1
                    we.save()

    # PROGRESSIVE OVERLOAD Intervention
    all_too_easy = all(log.effectiveness == 'Too Easy' for log in recent_logs)
    if all_too_easy:
        already_sent = AICoachMessage.objects.filter(
            user=user, 
            intervention_type='progressive_overload', 
            created_at__gte=today_start
        ).exists()
        
        if not already_sent:
            AICoachMessage.objects.create(
                user=user,
                message=f"You're crushing it! Your last 3 sets of {instance.exercise_name} were 'Too Easy'. Time to level up—try increasing your weight by 2.5kg or adding 2 reps next time.",
                intervention_type='progressive_overload'
            )
