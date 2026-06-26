class DemoData {
  static Map<String, dynamic> user({
    String name = 'Javier',
    String email = 'demo@flashdrop.cl',
    String phone = '+56 9 5555 1212',
  }) {
    return {
      'id': 1,
      'name': name,
      'lastName': 'Gessof',
      'email': email,
      'phone': phone,
      'rut': '12.345.678-9',
      'photo': null,
      'session_token': 'JWT demo-portfolio-token',
      'roles': roles,
    };
  }

  static const roles = [
    {'id': 1, 'name': 'Cliente', 'image': '', 'route': '/client/products/list'},
    {
      'id': 2,
      'name': 'Restaurante',
      'image': '',
      'route': '/restaurant/orders/list',
    },
    {
      'id': 3,
      'name': 'Repartidor',
      'image': '',
      'route': '/delivery/orders/list',
    },
  ];

  static const products = [
    {
      'name': 'Burger doble',
      'restaurant': 'Urban Burger',
      'price': '\$8.990',
      'time': '25-35 min',
      'image': 'assets/img/burger1.png',
      'tag': 'Mas vendido',
    },
    {
      'name': 'Pizza pepperoni',
      'restaurant': 'Pizza Norte',
      'price': '\$11.500',
      'time': '30-40 min',
      'image': 'assets/img/pizza.png',
      'tag': 'Familiar',
    },
    {
      'name': 'Combo delivery',
      'restaurant': 'Flash Market',
      'price': '\$6.490',
      'time': '15-25 min',
      'image': 'assets/img/bag.png',
      'tag': 'Express',
    },
  ];

  static const restaurantOrders = [
    {
      'code': '#FD-1048',
      'client': 'Camila Torres',
      'items': '2 burgers, 1 bebida',
      'status': 'Preparando',
      'amount': '\$18.480',
    },
    {
      'code': '#FD-1049',
      'client': 'Diego Perez',
      'items': '1 pizza familiar',
      'status': 'Listo para retiro',
      'amount': '\$11.500',
    },
    {
      'code': '#FD-1050',
      'client': 'Valentina Rojas',
      'items': '3 combos express',
      'status': 'Nuevo pedido',
      'amount': '\$19.470',
    },
  ];

  static const deliveryOrders = [
    {
      'code': '#FD-1048',
      'from': 'Urban Burger',
      'to': 'Av. Providencia 1200',
      'status': 'Retirar pedido',
      'distance': '2.4 km',
    },
    {
      'code': '#FD-1049',
      'from': 'Pizza Norte',
      'to': 'Los Leones 850',
      'status': 'En camino',
      'distance': '4.1 km',
    },
    {
      'code': '#FD-1050',
      'from': 'Flash Market',
      'to': 'Nueva Costanera 3900',
      'status': 'Entregado',
      'distance': '1.8 km',
    },
  ];
}
