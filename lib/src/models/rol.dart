class Rol {
  int? id;
  String? name;
  String? image;
  String? route;

  Rol({
    required this.id,
    required this.name,
    required this.image,
    required this.route,
  });

  factory Rol.fromJson(Map<String, dynamic> json) => Rol(
    id: json['id'] is String ? int.tryParse(json['id']) : json['id'],
    name: json['name'],
    image: json['image'],
    route: json['route'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'image': image,
    'route': route,
  };
}
