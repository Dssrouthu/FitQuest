from datetime import date as today_date
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db import transaction
from .models import FoodItem, DietPlan, Meal, MealItem, Supplement, DietSchedule, Recipe, RecipeIngredient, MealCompletion
from .serializers import FoodItemSerializer, DietPlanSerializer, DietScheduleSerializer, RecipeSerializer
from quests.models import Quest


# 1. PANTRY (List & Create)
class PantryView(generics.ListCreateAPIView):
    serializer_class = FoodItemSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        from django.db.models import Q
        return FoodItem.objects.filter(Q(coach=self.request.user) | Q(is_global=True))

    def perform_create(self, serializer):
        serializer.save(coach=self.request.user)


# 2. PANTRY ITEM (Delete)
class PantryItemView(generics.DestroyAPIView):
    queryset = FoodItem.objects.all()
    serializer_class = FoodItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        from django.db.models import Q
        return FoodItem.objects.filter(Q(coach=self.request.user) | Q(is_global=True))


# 3. DIET PLANS (List)
class DietPlanListView(generics.ListAPIView):
    serializer_class = DietPlanSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        return DietPlan.objects.filter(coach=self.request.user)


# 4. CREATE FULL PLAN
class CreateDietPlanView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        data = request.data
        try:
            with transaction.atomic():
                # A. Create Plan
                if request.user.role == 'RECRUIT':
                    plan = DietPlan.objects.create(
                        coach=None,
                        name=data['name'],
                        description=data.get('description', ''),
                        water_target_liters=data.get('water_target', 3.0)
                    )
                    plan.assigned_to.add(request.user)

                    # Auto-schedule for recruits: every day of the week
                    days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
                    for day in days:
                        DietSchedule.objects.update_or_create(
                            recruit=request.user,
                            day_of_week=day,
                            defaults={'diet_plan': plan, 'coach': None}
                        )
                else:
                    plan = DietPlan.objects.create(
                        coach=request.user,
                        name=data['name'],
                        description=data.get('description', ''),
                        water_target_liters=data.get('water_target', 3.0)
                    )

                # B. Add Supplements
                for supp in data.get('supplements', []):
                    Supplement.objects.create(plan=plan, name=supp['name'], dosage=supp['dosage'])

                # C. Add Meals & Items
                total_cals, total_prot, total_carbs, total_fats = 0, 0, 0, 0

                for meal_data in data.get('meals', []):
                    meal = Meal.objects.create(plan=plan, name=meal_data['name'], order=meal_data.get('order', 1))

                    for item in meal_data.get('items', []):
                        food = FoodItem.objects.get(id=item['food_id'])
                        qty = float(item['quantity'])
                        MealItem.objects.create(meal=meal, food_item=food, quantity=qty)

                        total_cals += food.calories * qty
                        total_prot += food.protein * qty
                        total_carbs += food.carbs * qty
                        total_fats += food.fats * qty

                # D. Update Totals
                plan.total_calories = round(total_cals)
                plan.total_protein = round(total_prot)
                plan.total_carbs = round(total_carbs)
                plan.total_fats = round(total_fats)
                plan.save()

                return Response({"message": "Diet Plan Created", "id": plan.id}, status=201)
        except Exception as e:
            return Response({"error": str(e)}, status=400)


# 5. ASSIGN PLAN (Bulk Assign)
class AssignDietView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        plan_id = request.data.get('plan_id')
        recruit_ids = request.data.get('recruit_ids')
        xp_reward = int(request.data.get('xp_reward', 100))
        coin_reward = int(request.data.get('coin_reward', 10))
        auto_quest = request.data.get('auto_quest', True)

        try:
            plan = DietPlan.objects.get(id=plan_id, coach=request.user)
            recruits = plan.coach.recruits.filter(id__in=recruit_ids)
            plan.assigned_to.add(*recruits)

            quest_id = None
            if auto_quest and recruits.exists():
                quest = Quest.objects.create(
                    coach=request.user,
                    title=f"Complete: {plan.name}",
                    description=f"Follow your assigned diet plan '{plan.name}'",
                    xp_reward=xp_reward,
                    coin_reward=coin_reward,
                    difficulty='MEDIUM',
                    is_auto_generated=True,
                )
                quest.assigned_to.add(*recruits)
                quest_id = quest.id

            return Response({
                "message": f"Assigned to {recruits.count()} recruits.",
                "quest_id": quest_id,
            })
        except DietPlan.DoesNotExist:
            return Response({"error": "Plan not found"}, status=404)


# 6. UPDATE DIET PLAN (General Info)
class UpdateDietPlanView(generics.RetrieveUpdateDestroyAPIView):
    queryset = DietPlan.objects.all()
    serializer_class = DietPlanSerializer
    permission_classes = [permissions.IsAuthenticated]


# 7. UPDATE SINGLE MEAL (New Feature)
class UpdateMealView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            from django.db.models import Q
            meal = Meal.objects.get(
                id=pk,
                plan__in=DietPlan.objects.filter(
                    Q(coach=request.user) | Q(coach__isnull=True, assigned_to=request.user)
                )
            )

            # 1. Clear old items
            meal.items.all().delete()

            # 2. Add new items
            total_cals, total_prot, total_carbs, total_fats = 0, 0, 0, 0

            for item_data in request.data.get('items', []):
                food = FoodItem.objects.get(id=item_data['food_id'])
                qty = float(item_data['quantity'])
                MealItem.objects.create(meal=meal, food_item=food, quantity=qty)

                # Sum for Meal totals (optional, but good for plan recalc)
                total_cals += food.calories * qty
                total_prot += food.protein * qty
                total_carbs += food.carbs * qty
                total_fats += food.fats * qty

            # 3. Recalculate PLAN totals
            plan = meal.plan
            # Reset plan totals to 0 and sum up ALL meals
            p_cals, p_prot, p_carbs, p_fats = 0, 0, 0, 0
            for m in plan.meals.all():
                for i in m.items.all():
                    p_cals += i.food_item.calories * i.quantity
                    p_prot += i.food_item.protein * i.quantity
                    p_carbs += i.food_item.carbs * i.quantity
                    p_fats += i.food_item.fats * i.quantity

            plan.total_calories = round(p_cals)
            plan.total_protein = round(p_prot)
            plan.total_carbs = round(p_carbs)
            plan.total_fats = round(p_fats)
            plan.save()

            return Response({"message": "Meal updated", "plan_totals": plan.total_calories})
        except Exception as e:
            return Response({"error": str(e)}, status=400)


# 8. MANAGE WEEKLY SCHEDULE (New Feature)
class RecruitScheduleView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, recruit_id):
        schedules = DietSchedule.objects.filter(recruit_id=recruit_id)
        serializer = DietScheduleSerializer(schedules, many=True)
        return Response(serializer.data)

    def post(self, request, recruit_id):
        # Expects: {"day": "Monday", "plan_id": 5}
        day = request.data.get('day')
        plan_id = request.data.get('plan_id')

        schedule, created = DietSchedule.objects.get_or_create(
            recruit_id=recruit_id,
            day_of_week=day,
            defaults={'coach': request.user}
        )
        if plan_id:
            schedule.diet_plan_id = plan_id
            schedule.save()
        else:
            schedule.delete()  # Remove plan from that day

        return Response({"message": "Schedule updated"})


# 9. RECIPES
class RecipeListCreateView(generics.ListCreateAPIView):
    serializer_class = RecipeSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Recipe.objects.filter(coach=self.request.user).prefetch_related('ingredients__food_item')

    def perform_create(self, serializer):
        recipe = serializer.save(coach=self.request.user)
        for ing in self.request.data.get('ingredients', []):
            RecipeIngredient.objects.create(
                recipe=recipe,
                food_item_id=ing['food_item'],
                quantity=ing.get('quantity', 1.0),
            )


class RecipeDeleteView(generics.DestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Recipe.objects.filter(coach=self.request.user)


# 10. RECRUIT: Assigned Diet Plans
class RecruitAssignedDietPlansView(generics.ListAPIView):
    serializer_class = DietPlanSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        return self.request.user.assigned_diet_plans.prefetch_related(
            'meals__items__food_item', 'supplements').all()


# 11. RECRUIT: My Weekly Schedule (Phase 4)
class MyScheduleView(generics.ListAPIView):
    """GET /api/nutrition/my-schedule/ — returns schedule entries for the logged-in recruit."""
    serializer_class = DietScheduleSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        return DietSchedule.objects.filter(recruit=self.request.user).select_related('diet_plan')


# 12. MEAL COMPLETION — Create (photo required)
class CompleteMealView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        meal_name = request.data.get('meal_name', '').strip()
        if not meal_name:
            return Response({'error': 'meal_name required'}, status=400)

        photo_file = request.FILES.get('photo')
        diet_plan_id = request.data.get('diet_plan_id')

        # upsert: if already completed today, update photo
        completion, created = MealCompletion.objects.get_or_create(
            user=request.user,
            meal_name=meal_name,
            date=today_date.today(),
            defaults={'diet_plan_id': diet_plan_id},
        )

        if photo_file:
            completion.photo.save(
                f'meal_{request.user.id}_{meal_name}_{completion.date}.jpg',
                photo_file,
                save=True,
            )
        elif created:
            # allow completion without photo (measurements-only mode)
            completion.save()

        base = request.build_absolute_uri('/')[:-1]
        photo_url = (base + completion.photo.url) if completion.photo else None
        return Response({
            'id': completion.id,
            'meal_name': completion.meal_name,
            'date': str(completion.date),
            'photo_url': photo_url,
        }, status=status.HTTP_201_CREATED)


# 13. MEAL COMPLETIONS — List today's (or by date)
class MealCompletionsListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        date_str = request.query_params.get('date', str(today_date.today()))
        try:
            from datetime import datetime
            target_date = datetime.strptime(date_str, '%Y-%m-%d').date()
        except ValueError:
            target_date = today_date.today()

        completions = MealCompletion.objects.filter(
            user=request.user, date=target_date
        )
        base = request.build_absolute_uri('/')[:-1]
        return Response([{
            'id': c.id,
            'meal_name': c.meal_name,
            'date': str(c.date),
            'photo_url': (base + c.photo.url) if c.photo else None,
            'completed_at': str(c.completed_at),
        } for c in completions])


# 14. MEAL COMPLETION — Delete (undo)
class MealCompletionDeleteView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, pk):
        try:
            completion = MealCompletion.objects.get(id=pk, user=request.user)
            completion.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        except MealCompletion.DoesNotExist:
            return Response({'error': 'Not found'}, status=404)

# 15. ATHLETE: Own Self-Created Diet Plans
class AthleteOwnDietPlansView(generics.ListAPIView):
    serializer_class = DietPlanSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        return DietPlan.objects.filter(
            coach__isnull=True, assigned_to=self.request.user
        ).prefetch_related('meals__items__food_item', 'supplements')

# 16. ATHLETE: Supplements Tracking
from .models import SupplementLog
from datetime import date as date_today

class SupplementLogView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        date_str = request.query_params.get('date')
        if not date_str:
            date_str = date_today.today().isoformat()
            
        logs = SupplementLog.objects.filter(user=request.user, date=date_str)
        return Response([{
            'id': log.id,
            'supplement_name': log.supplement_name,
            'target_time': str(log.target_time) if log.target_time else None,
            'is_taken': log.is_taken,
        } for log in logs])

    def post(self, request):
        date_str = request.data.get('date', date_today.today().isoformat())
        name = request.data.get('supplement_name')
        
        if not name:
            return Response({'error': 'supplement_name required'}, status=400)
            
        log, created = SupplementLog.objects.get_or_create(
            user=request.user,
            supplement_name=name,
            date=date_str
        )
        
        if 'is_taken' in request.data:
            log.is_taken = request.data['is_taken']
        if 'target_time' in request.data:
            log.target_time = request.data['target_time']
            
        log.save()
        return Response({
            'id': log.id,
            'supplement_name': log.supplement_name,
            'target_time': str(log.target_time) if log.target_time else None,
            'is_taken': log.is_taken,
        })
        
    def delete(self, request):
        log_id = request.data.get('id')
        if not log_id:
            return Response({'error': 'id required'}, status=400)
        try:
            log = SupplementLog.objects.get(id=log_id, user=request.user)
            log.delete()
            return Response({'success': True})
        except SupplementLog.DoesNotExist:
            return Response({'error': 'not found'}, status=404)
