from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
from django.utils import timezone


# --- CUSTOM USER MANAGER ---
class CustomUserManager(BaseUserManager):
    def create_user(self, username, email, password=None, **extra_fields):
        if not email:
            raise ValueError('The Email field must be set')
        email = self.normalize_email(email)
        user = self.model(username=username, email=email, **extra_fields)
        if password:
            user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, username, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('role', 'HIGH_COUNCIL')
        return self.create_user(username, email, password, **extra_fields)


# --- MAIN USER MODEL ---
class CustomUser(AbstractUser):
    ROLE_CHOICES = (
        ('RECRUIT', 'Recruit'),
        ('GUILD_MASTER', 'Guild Master'),
        ('SUPER_COACH', 'Super Coach'),
        ('HIGH_COUNCIL', 'High Council'),
    )

    email = models.EmailField(unique=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='RECRUIT')

    # Profile Fields
    height = models.FloatField(null=True, blank=True)
    weight = models.FloatField(null=True, blank=True)
    activity_level = models.CharField(max_length=50, default="Sedentary")
    goal = models.CharField(max_length=50, default="General Fitness")
    age = models.IntegerField(null=True, blank=True)
    gender = models.CharField(max_length=10, choices=[('male','Male'),('female','Female')], null=True, blank=True)

    # Gamification
    xp = models.IntegerField(default=0)
    level = models.IntegerField(default=1)
    coin_balance = models.IntegerField(default=0)

    # Biometrics for 'The Anvil'
    # Stores cumulative volume (weight * reps) per muscle group
    muscle_volume = models.JSONField(default=dict, blank=True) 

    PLAYER_CLASS_CHOICES = (
        ('Vanguard', 'Vanguard'),
        ('Assassin', 'Assassin'),
        ('Ranger', 'Ranger'),
        ('Mage', 'Mage'),
    )
    player_class = models.CharField(max_length=50, choices=PLAYER_CLASS_CHOICES, null=True, blank=True)

    # Coaching Relationship
    # A recruit can have ONE coach. A coach has MANY recruits.
    coach = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        limit_choices_to={'role': 'GUILD_MASTER'},
        related_name='recruits'
    )

    # Super Coach supervises regular coaches
    super_coach = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        limit_choices_to={'role': 'SUPER_COACH'},
        related_name='managed_coaches',
    )

    # New Assignment Flag (For the notification panel)
    is_new_assignment = models.BooleanField(default=False)

    objects = CustomUserManager()

    def __str__(self):
        return f"{self.username} ({self.role})"


# --- COACH ACCESS KEYS ---
class CoachAccessKey(models.Model):
    KEY_TYPE_CHOICES = [('COACH', 'Coach'), ('SUPER_COACH', 'Super Coach')]

    key = models.CharField(max_length=10, unique=True)
    is_used = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    used_by = models.CharField(max_length=150, null=True, blank=True)
    key_type = models.CharField(
        max_length=20, choices=KEY_TYPE_CHOICES, default='COACH'
    )

    @staticmethod
    def generate_key():
        import random, string
        return ''.join(random.choices(string.digits, k=5))


# --- DIGITAL ASSESSMENT FORM ---
class AssessmentForm(models.Model):
    user = models.OneToOneField(CustomUser, on_delete=models.CASCADE, related_name='assessment')

    # Physical Measurements (Added Bicep, Chest, Thigh)
    waist_circumference = models.FloatField(help_text="Inches")
    bicep_size = models.FloatField(help_text="Inches", null=True, blank=True)
    chest_size = models.FloatField(help_text="Inches", null=True, blank=True)
    thigh_size = models.FloatField(help_text="Inches", null=True, blank=True)

    # Medical
    medical_history = models.TextField(blank=True, help_text="Past or present conditions")
    injuries = models.TextField(blank=True, help_text="Fractures, chronic pain")

    # Lifestyle & Diet
    food_preference = models.CharField(max_length=50, choices=[
        ('Vegan', 'Vegan'),
        ('Jain', 'Jain'),
        ('Lacto-Veg', 'Lacto-Vegetarian'),
        ('Ovo-Veg', 'Ovo-Vegetarian'),
        ('Pescatarian', 'Pescatarian'),
        ('Non-Veg', 'Non-Vegetarian')
    ])
    meals_per_day = models.IntegerField(default=3)
    typical_breakfast = models.TextField(blank=True)
    typical_lunch = models.TextField(blank=True)
    typical_dinner = models.TextField(blank=True)
    typical_snacks = models.TextField(blank=True)

    # Habits
    tea_coffee_cups = models.CharField(max_length=50, blank=True)
    alcohol_frequency = models.CharField(max_length=50, blank=True)
    food_allergies = models.TextField(blank=True)

    # Exercise History
    exercise_experience = models.TextField(blank=True, help_text="Years of experience")
    preferred_exercise = models.CharField(max_length=100, blank=True)
    days_available = models.CharField(max_length=100)

    submitted_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Assessment for {self.user.username}"