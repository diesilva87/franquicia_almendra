create schema franquicia_almendra;
use franquicia_almendra;

create table categoria(
id_categoria int not null primary key auto_increment,
nombre varchar(100) not null,
descripcion varchar (100)
);

create table productos (
id_producto int not null primary key auto_increment,
id_categoria int not null,
nombre varchar(100) not null,
sku varchar(100),
descripcion varchar(150),
constraint fk_productos_categoria
foreign key (id_categoria) references categoria(id_categoria)
);

create table costos(
id_producto int not null primary key,
id_categoria int not null,
categoria varchar(100) not null,
costo_reposicion decimal(10,2) not null,
constraint fk_costos_producto
foreign key (id_producto) references productos(id_producto),
constraint fk_costos_categoria
foreign key (id_categoria) references categoria(id_categoria)
);

create table franjas_horarias(
id_franja int not null primary key auto_increment,
hora time not null,
franja_horaria varchar (50) not null
);

create table precios(
id_producto int not null primary key,
id_categoria int not null,
nombre varchar(100),
precio_unit varchar(100) not null,
sku varchar(100),
descripcion varchar(150)
);

create table ventas(
id_venta int not null primary key auto_increment,
id_producto int not null,
fecha date not null,
hora time not null,
id_franja int not null,
cantidad decimal (10,0) not null,
precio_unit decimal(10,2) not null,
PxQ decimal(10,2) as (cantidad * precio_unit),
constraint fk_ventas_producto
foreign key (id_producto) references productos (id_producto),
constraint fk_ventas_franja
foreign key (id_franja) references franjas_horarias (id_franja),
constraint fk_ventas_precio_unit
foreign key (id_producto) references precios (id_producto)
);

