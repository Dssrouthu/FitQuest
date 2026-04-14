from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.http import JsonResponse

from django.views.decorators.csrf import csrf_exempt

@csrf_exempt
def health_check(request):
    return JsonResponse({"status": "ok", "message": "FitQuest API is running"})

urlpatterns = [
    path('', health_check), # Root also returns health check
    path('health/', health_check),
    path('health', health_check),
    path('admin/', admin.site.urls),
    
    # Connect our apps here:
    path('api/users/', include('users.urls')),
    
    # We will uncomment these later as we build them:
     path('api/exercises/', include('exercises.urls')),
     path('api/workouts/', include('workouts.urls')),
     path('api/analytics/', include('analytics.urls')),
     path('api/nutrition/', include('nutrition.urls')),
     path('api/ai/', include('ai_services.urls')),
     path('api/quests/', include('quests.urls')),
     path('api/shop/',   include('shop.urls')),
     path('api/chat/',   include('chat.urls')),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)