-- PARTE 1 
#Creamos una base de datos para pasar a limpio todos los datos de Learndata_crudo sin modificar el original.
CREATE SCHEMA learndata_proyecto;
-- Creamos la primera tabla de productos.
select * from learndata_crudo.raw_productos_wocommerce; #verificamos como vienen los datos.
CREATE TABLE learndata_proyecto.dim_productos (
pk_idproducto INT,
tipo_producto_1 VARCHAR (50),
tipo_producto_2 VARCHAR (50),
nombre_producto VARCHAR (100), 
ind_publicado INT,
ind_visibilidad_catalogo INT,
ind_inventario INT,
estado_inventario VARCHAR (50),
ind_vendido_ind INT,
precio_curso DECIMAL (10,2),
categoria VARCHAR (50),
PRIMARY KEY (pk_idproducto)
);

#Creamos una consulta con los datos que queremos insertar
INSERT INTO learndata_proyecto.dim_productos 
SELECT 
id,
substr(tipo,1,locate(',',tipo)-1) as tipo_1,
substr(tipo,locate(',',tipo)+1) as tipo_2,
nombre,
publicado,
CASE 
when visibilidad_catalogo = 'visible' then 1 
else 0
end ind_visibilidad_catalogo,
en_inventario,
inventario,
case
when estado_impuesto ='none' then 0
else 1
end ind_vend_ind,
precio_normal,
categorias
FROM learndata_crudo.raw_productos_wocommerce
WHERE id is not null; 
SELECT * FROM learndata_proyecto.dim_productos ;

-- Creamos la primera tabla de clientes.
select * from learndata_crudo.raw_clientes_wocommerce;

CREATE TABLE learndata_proyecto.dim_clientes (
pk_idcliente INT,
nombre_cliente VARCHAR (50),
region VARCHAR (50),
pais VARCHAR (50),
direccion_cliente VARCHAR (100),
codigo_postal VARCHAR (30),
fecha_creacion DATE,
rol VARCHAR (50)
);
#Creamos una consulta con los datos que queremos insertar
INSERT INTO learndata_proyecto.dim_clientes
SELECT 
id,
CONCAT(json_unquote(json_extract(billing, '$.first_name')),' ', last_name) as nombre_cliente,
json_unquote(json_extract(billing, '$.Region')) as region,
json_unquote(json_extract(billing, '$.country')) as pais,
json_unquote(json_extract(billing, '$.address_1')) as direccion_cliente,
postcode,
str_to_date(date_created, '%d/%m/%Y %H:%i:%s') as fecha_creacion,
role as rol
FROM learndata_crudo.raw_clientes_wocommerce;

SELECT * FROM learndata_proyecto.dim_clientes;

;
SELECT  str_to_date(date_created, '%d/%m/%Y %H:%i:%s') FROM learndata_crudo.raw_clientes_wocommerce;
select max(char_length((json_extract(billing, '$.address_1')))) 
FROM learndata_crudo.raw_clientes_wocommerce;

-- Creamos la tabla de pedidos.

SELECT * FROM learndata_crudo.raw_pedidos_wocommerce;
CREATE TABLE learndata_proyecto.fac_pedidos (
pkid_pedido INT,
sku VARCHAR (20),
estado_pedido VARCHAR (50),
fecha_pedido DATE,
id_cliente INT,
metodo_pago VARCHAR (50),
descuento_carrito INT, 
subtotal_pago decimal (10,2),
importe_envio decimal (10,2),
venta_total decimal (10,2),
id_producto INT,
nombre_producto VARCHAR (100),
cantidad_producto INT,
coste_producto decimal (10,2),
primary key (pkid_pedido)
);

#Creamos una consulta con los datos que queremos insertar
INSERT INTO learndata_proyecto.fac_pedidos 
SELECT
numero_de_pedido,
sku,
estado_de_pedido,
str_to_date(fecha_de_pedido, '%Y-%m-%d %H:%i') as fecha_pedido,
`id cliente` as id_cliente,
case 
when titulo_metodo_de_pago Like '%Stripe%' 
then  'Stripe'
ELSE 'Tarjeta'
END AS metodo_pago,
importe_de_descuento_del_carrito,
importe_subtotal_carrito,
importe_envio_pedido,
importe_total_pedido,
dim.pk_idproducto,
nombre_del_articulo,
cantidad,
coste_articulo 
FROM learndata_crudo.raw_pedidos_wocommerce p
LEFT JOIN learndata_proyecto.dim_productos dim
ON replace(nombre_del_articulo,'dashborads','dashboards') = dim.nombre_producto; 

SELECT * FROM learndata_proyecto.fac_pedidos;

CREATE TABLE learndata_proyecto.fac_pagos_stripe (
pk_idtransaccion VARCHAR (50),
fecha_pago timestamp,
id_pedido int,
moneda VARCHAR (3),
importe_pago decimal (10,2),
comision_pago decimal (10,2),
neto_pago decimal (10,2),
tipo_pago VARCHAR (50),
primary key (pk_idtransaccion)
);
#Creamos una consulta con los datos que queremos insertar.
INSERT INTO learndata_proyecto.fac_pagos_stripe
SELECT 
id,
str_to_date(created, '%Y-%m-%dT %H:%i:%sZ') as  fecha_pago,
RIGHT(description, 5) as id_pedido,
currency,
amount,
CAST(replace(fee,',', '.') as decimal (10,2)) as comision_pago,
CAST(replace(net,',','.') as decimal (10,2)) as neto_pago,
`type` as tipo
 FROM learndata_crudo.raw_pagos_stripe;

-- Agregamos el 'id_cliente' como primary key que es unmpaos que nos falto.

ALTER TABLE learndata_proyecto.dim_clientes 
ADD primary key ( pk_idcliente);

-- Ahora como paso extra y mejorar nuestro trabajo dejamos algunos resultados que pueden ser de interes para los departamentos.
# 1- Productos que generan mas ingresos:
SELECT
nombre_producto,
SUM(cantidad_producto) AS total_vendido,
SUM(coste_producto) AS total_facturado
FROM learndata_proyecto.fac_pedidos
GROUP BY nombre_producto
ORDER BY total_facturado desc;

# 2- Clientes más valiosos.
SELECT c.nombre_cliente,
count(pe.pkid_pedido) as total_pedidos,
sum(pe.venta_total) as total_vendido
FROM learndata_proyecto.dim_clientes c 
LEFT JOIN learndata_proyecto.fac_pedidos pe
ON c.pk_idcliente = pe.id_cliente
GROUP BY nombre_cliente
order by total_vendido desc
limit 5;

# 3- Total de ventas mensuales.
-- Opcion 1 vemos los meses mas fuertes
SELECT month(fecha_pedido) as mes,
sum(venta_total) as total_venta
FROM learndata_proyecto.fac_pedidos
group by mes
order by total_venta desc;
-- Opcion 2 vemos los meses pero por año.
SELECT date_format(fecha_pedido, '%Y-%m') as mes,
sum(venta_total) as total_venta
FROM learndata_proyecto.fac_pedidos
group by mes
order by total_venta desc;

# 4- Metodo de pago más utilizado.
SELECT metodo_pago, 
count(*) as tipo_pago
FROM learndata_proyecto.fac_pedidos
group by metodo_pago
order by tipo_pago;

 


