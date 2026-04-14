from rest_framework import generics, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from .models import ShopItem, Purchase, SuperCoachService, ServicePurchase
from .serializers import ShopItemSerializer, PurchaseSerializer


# ── Coach: list their shop items ─────────────────────────────────────────────
class CoachShopView(generics.ListAPIView):
    serializer_class   = ShopItemSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class   = None

    def get_queryset(self):
        return ShopItem.objects.filter(coach=self.request.user).order_by('-created_at')


# ── Coach: create a shop item ─────────────────────────────────────────────────
class CreateShopItemView(generics.CreateAPIView):
    serializer_class   = ShopItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(coach=self.request.user)


# ── Coach: update / delete a shop item ───────────────────────────────────────
class ShopItemDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class   = ShopItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return ShopItem.objects.filter(coach=self.request.user)


# ── Coach: view all purchases for their shop ──────────────────────────────────
class CoachPurchasesView(generics.ListAPIView):
    serializer_class   = PurchaseSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class   = None

    def get_queryset(self):
        return Purchase.objects.filter(
            item__coach=self.request.user).order_by('-purchased_at')


# ── Coach: mark a purchase as fulfilled ───────────────────────────────────────
class FulfillPurchaseView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            purchase = Purchase.objects.get(id=pk, item__coach=request.user)
        except Purchase.DoesNotExist:
            return Response({'error': 'Purchase not found'}, status=status.HTTP_404_NOT_FOUND)

        purchase.is_fulfilled = True
        purchase.save()
        return Response({'message': 'Marked as fulfilled'})


# ── Recruit: view available shop items (from their coach) ────────────────────
class AvailableShopView(generics.ListAPIView):
    serializer_class   = ShopItemSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class   = None

    def get_queryset(self):
        coach = self.request.user.coach
        if not coach:
            return ShopItem.objects.none()
        return ShopItem.objects.filter(coach=coach, is_active=True).order_by('-created_at')


# ── Recruit: purchase an item (deducts coins) ─────────────────────────────────
class PurchaseItemView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        item_id = request.data.get('item_id')

        try:
            item = ShopItem.objects.get(id=item_id, is_active=True)
        except ShopItem.DoesNotExist:
            return Response({'error': 'Item not found'}, status=status.HTTP_404_NOT_FOUND)

        recruit = request.user

        # Verify the item belongs to the recruit's coach
        if recruit.coach != item.coach:
            return Response(
                {'error': 'Item not available from your coach'},
                status=status.HTTP_403_FORBIDDEN)

        if recruit.coin_balance < item.coin_price:
            return Response(
                {'error': f'Not enough coins (need {item.coin_price}, have {recruit.coin_balance})'},
                status=status.HTTP_400_BAD_REQUEST)

        recruit.coin_balance -= item.coin_price
        recruit.save()

        purchase = Purchase.objects.create(recruit=recruit, item=item)

        return Response({
            'message':    f'Purchased {item.name}!',
            'new_coins':  recruit.coin_balance,
            'purchase_id': purchase.id,
        })


# ── Recruit: view their purchase history ─────────────────────────────────────
class MyPurchasesView(generics.ListAPIView):
    serializer_class   = PurchaseSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class   = None

    def get_queryset(self):
        return Purchase.objects.filter(recruit=self.request.user).order_by('-purchased_at')


# ── Super Coach: list active services (recruits browse) ──────────────────────
class SCServiceListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role == 'RECRUIT':
            # Show services from SC in the recruit's chain (coach's super_coach)
            coach = user.coach
            sc = coach.super_coach if coach else None
            if sc:
                services = SuperCoachService.objects.filter(
                    super_coach=sc, is_active=True).order_by('-created_at')
            else:
                # Marketplace fallback: show all active SC services
                services = SuperCoachService.objects.filter(
                    is_active=True).order_by('-created_at')
        elif user.role == 'SUPER_COACH':
            services = SuperCoachService.objects.filter(
                super_coach=user).order_by('-created_at')
        else:
            return Response({'error': 'Forbidden'}, status=403)

        return Response([{
            'id': s.id,
            'name': s.name,
            'description': s.description,
            'coin_price': s.coin_price,
            'is_active': s.is_active,
            'sc_username': s.super_coach.username,
            'purchase_count': s.purchases.count(),
        } for s in services])


# ── Super Coach: create a service ────────────────────────────────────────────
class SCServiceCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        if request.user.role != 'SUPER_COACH':
            return Response({'error': 'Only Super Coaches can create services'}, status=403)
        name = request.data.get('name', '').strip()
        if not name:
            return Response({'error': 'name required'}, status=400)
        service = SuperCoachService.objects.create(
            super_coach=request.user,
            name=name,
            description=request.data.get('description', ''),
            coin_price=int(request.data.get('coin_price', 0)),
        )
        return Response({'id': service.id, 'name': service.name}, status=201)


# ── Super Coach: manage own service ──────────────────────────────────────────
class SCServiceDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def _get_service(self, request, pk):
        try:
            return SuperCoachService.objects.get(id=pk, super_coach=request.user)
        except SuperCoachService.DoesNotExist:
            return None

    def get(self, request, pk):
        svc = self._get_service(request, pk)
        if not svc:
            return Response({'error': 'Not found'}, status=404)
        return Response({
            'id': svc.id,
            'name': svc.name,
            'description': svc.description,
            'coin_price': svc.coin_price,
            'is_active': svc.is_active,
            'purchase_count': svc.purchases.count(),
        })

    def put(self, request, pk):
        svc = self._get_service(request, pk)
        if not svc:
            return Response({'error': 'Not found'}, status=404)
        if 'name' in request.data:
            svc.name = request.data['name']
        if 'description' in request.data:
            svc.description = request.data['description']
        if 'coin_price' in request.data:
            svc.coin_price = int(request.data['coin_price'])
        if 'is_active' in request.data:
            svc.is_active = bool(request.data['is_active'])
        svc.save()
        return Response({'id': svc.id, 'name': svc.name, 'is_active': svc.is_active})

    def delete(self, request, pk):
        svc = self._get_service(request, pk)
        if not svc:
            return Response({'error': 'Not found'}, status=404)
        svc.delete()
        return Response(status=204)


# ── Recruit: purchase a Super Coach service ───────────────────────────────────
class SCServicePurchaseView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        service_id = request.data.get('service_id')
        try:
            service = SuperCoachService.objects.get(id=service_id, is_active=True)
        except SuperCoachService.DoesNotExist:
            return Response({'error': 'Service not found'}, status=404)

        recruit = request.user
        if recruit.coin_balance < service.coin_price:
            return Response({
                'error': f'Not enough coins (need {service.coin_price}, have {recruit.coin_balance})'
            }, status=400)

        recruit.coin_balance -= service.coin_price
        recruit.save()

        purchase = ServicePurchase.objects.create(recruit=recruit, service=service)
        return Response({
            'message': f'Purchased {service.name}!',
            'new_coins': recruit.coin_balance,
            'purchase_id': purchase.id,
        })


# ── Super Coach: view all service purchases ───────────────────────────────────
class SCServicePurchasesView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        if request.user.role != 'SUPER_COACH':
            return Response({'error': 'Forbidden'}, status=403)
        purchases = ServicePurchase.objects.filter(
            service__super_coach=request.user
        ).order_by('-purchased_at').select_related('recruit', 'service')
        return Response([{
            'id': p.id,
            'service_name': p.service.name,
            'recruit_username': p.recruit.username,
            'purchased_at': str(p.purchased_at),
            'is_fulfilled': p.is_fulfilled,
        } for p in purchases])


# ── Super Coach: fulfill a service purchase ───────────────────────────────────
class SCFulfillPurchaseView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            purchase = ServicePurchase.objects.get(id=pk, service__super_coach=request.user)
        except ServicePurchase.DoesNotExist:
            return Response({'error': 'Purchase not found'}, status=404)
        purchase.is_fulfilled = True
        purchase.save()
        return Response({'message': 'Marked as fulfilled'})


# ── Recruit: view my service purchases ────────────────────────────────────────
class MyServicePurchasesView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        purchases = ServicePurchase.objects.filter(
            recruit=request.user
        ).order_by('-purchased_at').select_related('service', 'service__super_coach')
        return Response([{
            'id': p.id,
            'service_name': p.service.name,
            'sc_username': p.service.super_coach.username,
            'coin_price': p.service.coin_price,
            'purchased_at': str(p.purchased_at),
            'is_fulfilled': p.is_fulfilled,
        } for p in purchases])
