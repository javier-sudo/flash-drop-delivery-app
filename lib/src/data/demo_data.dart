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

  // ── Catálogo demo con la misma forma que /catalog/restaurants y
  // /catalog/products del Gateway. image, rating y deliveryTime son campos
  // opcionales: la interfaz los muestra solo si vienen.
  static String _img(String id) =>
      'https://images.unsplash.com/photo-$id?w=800&q=75&auto=format&fit=crop';

  static final catalogRestaurants = <Map<String, dynamic>>[
    {
      'id': 1,
      'name': 'Urban Burger',
      'address': 'Av. Providencia 1650, Providencia',
      'image': _img('1561758033-d89a9ad46330'),
      'description': 'Hamburguesas artesanales',
      'rating': 4.8,
      'deliveryTime': 25,
    },
    {
      'id': 2,
      'name': 'Pizza Norte',
      'address': 'Av. Independencia 1200, Independencia',
      'image': _img('1513104890138-7c749659a591'),
      'description': 'Pizzas al horno de leña',
      'rating': 4.6,
      'deliveryTime': 35,
    },
    {
      'id': 3,
      'name': 'Sushi Kento',
      'address': 'Av. Apoquindo 4400, Las Condes',
      'image': _img('1553621042-f6e147245754'),
      'description': 'Rolls, nigiris y tablas',
      'rating': 4.7,
      'deliveryTime': 40,
    },
    {
      'id': 4,
      'name': 'Flash Market',
      'address': 'Av. Matta 800, Santiago',
      'image': _img('1542838132-92c53300491e'),
      'description': 'Minimarket express',
      'rating': 4.5,
      'deliveryTime': 20,
    },
  ];

  static final catalogProducts = <Map<String, dynamic>>[
    _product(
      101,
      1,
      1,
      'Hamburguesas',
      'Burger doble',
      'Doble carne, cheddar y salsa de la casa.',
      8990,
      '1572802419224-296b0aeee0d9',
    ),
    _product(
      102,
      1,
      1,
      'Hamburguesas',
      'Clásica',
      'Carne 180 g, lechuga, tomate y cheddar.',
      6990,
      '1568901346375-23c9450c58cd',
    ),
    _product(
      103,
      1,
      1,
      'Hamburguesas',
      'BBQ Bacon',
      'Tocino crocante y salsa BBQ.',
      8490,
      '1586190848861-99aa4a171e90',
    ),
    _product(
      104,
      1,
      2,
      'Acompañamientos',
      'Papas rústicas',
      'Porción mediana con sal de mar.',
      2990,
      '1594212699903-ec8a3eca50f5',
    ),
    _product(
      201,
      2,
      3,
      'Pizzas',
      'Pizza pepperoni',
      'Mozzarella y pepperoni. Familiar.',
      11500,
      '1513104890138-7c749659a591',
    ),
    _product(
      202,
      2,
      3,
      'Pizzas',
      'Margarita',
      'Tomate, mozzarella fresca y albahaca.',
      9990,
      '1565299624946-b28f40a0ae38',
    ),
    _product(
      203,
      2,
      4,
      'Pastas',
      'Tagliatelle al pesto',
      'Pasta fresca con pesto y parmesano.',
      8490,
      '1551183053-bf91a1d81141',
    ),
    _product(
      301,
      3,
      5,
      'Rolls',
      'Acevichado roll',
      'Salmón, palta y salsa acevichada (10 piezas).',
      8990,
      '1579871494447-9811cf80d66c',
    ),
    _product(
      302,
      3,
      5,
      'Rolls',
      'Tabla Kento',
      'Selección del chef, 30 piezas.',
      22990,
      '1611143669185-af224c5e3252',
    ),
    _product(
      303,
      3,
      6,
      'Entradas',
      'Gyozas',
      'Empanaditas de cerdo (5 unidades).',
      5490,
      '1504674900247-0877df9cc836',
    ),
    _product(
      401,
      4,
      7,
      'Despensa',
      'Combo delivery',
      'Bebida, snack y chocolate.',
      6490,
      '1604719312566-8912e9227c6a',
    ),
    _product(
      402,
      4,
      8,
      'Frutas',
      'Caja de frutas',
      'Selección de estación, 3 kg.',
      8990,
      '1610832958506-aa56368176cf',
    ),
    _product(
      403,
      4,
      9,
      'Panadería',
      'Pan de masa madre',
      'Hogaza de 800 g.',
      4490,
      '1509440159596-0249088772ff',
    ),
  ];

  static Map<String, dynamic> _product(
    int id,
    int restaurantId,
    int categoryId,
    String categoryName,
    String name,
    String description,
    int price,
    String imageId,
  ) => {
    'id': id,
    'restaurantId': restaurantId,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'name': name,
    'description': description,
    'price': price,
    'image': _img(imageId),
  };

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
