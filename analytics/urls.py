from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    WorkoutLogViewSet, DailyActivityView, BodyProgressListView,
    BodyProgressDeleteView, PhotoGalleryView, AthleteBodyProgressView,
    HeartbeatView, TeamActivityView, LogSetView, MySetLogsView,
    AthleteSetLogsView, AthleteAnalyticsSummaryView, SelfTransformationsView,
    DailySummaryView, GhostDuelView,
)

router = DefaultRouter()
router.register(r'logs', WorkoutLogViewSet, basename='workoutlog')

urlpatterns = [
    path('', include(router.urls)),
    path('daily/', DailyActivityView.as_view(), name='daily-activity'),
    path('daily-summary/', DailySummaryView.as_view(), name='daily-summary'),
    path('body-progress/', BodyProgressListView.as_view(), name='body-progress'),
    path('body-progress/<int:pk>/', BodyProgressDeleteView.as_view(), name='body-progress-delete'),
    path('photos/', PhotoGalleryView.as_view(), name='photo-gallery'),
    path('athlete/<int:athlete_id>/body-progress/', AthleteBodyProgressView.as_view(), name='athlete-body-progress'),
    path('heartbeat/', HeartbeatView.as_view(), name='heartbeat'),
    path('team-activity/', TeamActivityView.as_view(), name='team-activity'),
    path('log-set/', LogSetView.as_view(), name='log-set'),
    path('my-sets/', MySetLogsView.as_view(), name='my-sets'),
    path('ghost-duel/<int:set_id>/', GhostDuelView.as_view(), name='ghost-duel'),
    path('athlete/<int:athlete_id>/sets/', AthleteSetLogsView.as_view(), name='athlete-sets'),
    path('athlete/<int:athlete_id>/summary/', AthleteAnalyticsSummaryView.as_view(), name='athlete-summary'),
    path('my-transformations/', SelfTransformationsView.as_view(), name='my-transformations'),
]
