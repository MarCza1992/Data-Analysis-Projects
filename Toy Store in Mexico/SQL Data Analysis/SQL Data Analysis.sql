-- data overall looks very clean, nothing much to do except changing data type (text -> date) in 2 columns, changing price values into decimal type and setting primary/foreign keys

alter table sales change `Date` Sale_Date date;
alter table stores change Store_Open_Date Store_Open_Date date;

update products
set Product_Cost = replace(Product_Cost, "$", ""),
	Product_Price = replace(Product_Price, "$", "");
    
alter table products change Product_Cost Product_Cost decimal(65,2);
alter table products change Product_Price Product_Price decimal(65,2);

ALTER TABLE sales
CHANGE COLUMN Sale_ID Sale_ID INT NOT NULL,
ADD PRIMARY KEY (Sale_ID);

ALTER TABLE products
CHANGE COLUMN Product_ID Product_ID INT NOT NULL,
ADD PRIMARY KEY (Product_ID);

ALTER TABLE stores
CHANGE COLUMN Store_ID Store_ID INT NOT NULL,
ADD PRIMARY KEY (Store_ID);

						-- QUERIES TO ANSWER SOME INTERESTING QUESTIONS FOR DATA ANALYSIS
                        
-- what categories of products bring the biggest profit? are they the same in every location?

select p.Product_Category, sum((p.Product_Price - p.Product_Cost) * sa.units) as profit
from products as p
join sales as sa
	on p.Product_ID = sa.Product_ID
group by p.Product_Category
order by 2 desc; -- the biggest proft overall comes from Toys and Electronics products

with table1 as
(
select st.Store_Name, p.Product_Category, sum((p.Product_Price - p.Product_Cost) * sa.units) as profit,
rank() over(partition by st.Store_Name order by sum((p.Product_Price - p.Product_Cost) * sa.units) desc) as rn
from products as p
join sales as sa
	on p.Product_ID = sa.Product_ID
join stores as st
	on sa.Store_ID = st.Store_ID
group by st.Store_Name, p.Product_Category
)
select Product_Category, count(*) as 'Total number of stores'
from table1
where rn <= 2
group by Product_Category
order by 2 desc; -- Thats semi true. in most locations, the highest profits come from Toys and Electronics, but there are some exceptions where categories like Art & Crafts or Games generate the highest profit

-- Can any seasonal trends or patterns be identified in the sales data?

select date_format(sa.Sale_Date, '%W') as WeekDay, sum((p.Product_Price - p.Product_Cost) * sa.units) as profit
from products as p
join sales as sa
	on p.Product_ID = sa.Product_ID
group by WeekDay
order by 1; -- the biggest overall profits comes from friday and saturday weekdays

select date_format(sa.Sale_Date, '%Y-%m') as Month, sum((p.Product_Price - p.Product_Cost) * sa.units) as profit
from products as p
join sales as sa
	on p.Product_ID = sa.Product_ID
group by Month
order by 1; -- december is the month with the biggest profit, but we dont have enough data to identify that trend (less than 2years), 2023 is overall much better year for Toy Store in profits if we compare it to data in 2022

select date_format(sa.Sale_Date, '%Y-%m') as Month, sum(sa.units) as Units_Sold
from products as p
join sales as sa
	on p.Product_ID = sa.Product_ID
where p.Product_Category = 'Sports & OutDoors'
group by Month
order by 1; -- we can notice that in 2022 "Sports & OutDoors" category products got much bigger unit sale on June and July

-- what is the total cost of goods stored in inventory? How long will the inventory last without any orders?

select st.Store_Name, sum(i.Stock_On_Hand * p.Product_Cost) as Cost_of_goods
from inventory as i
join stores as st
	on i.Store_ID = st.Store_ID
join products as p
	on i.Product_ID = p.Product_ID
group by st.Store_Name
order by st.Store_Name; -- Total cost of goods stored in inventory in every store

with table1 as
(
select st.Store_ID, st.Store_Name, round(sum(sa.Units) / 30, 0) as avg_daily_units_sold
from sales as sa
join stores as st
	on sa.Store_ID = st.Store_ID
where sa.Sale_Date >= (Select max(Sale_Date) from sales) - interval 30 day
group by st.Store_ID, st.Store_Name
order by st.Store_ID
), table2 as
(
select t1.store_ID, t1.Store_Name, t1.avg_daily_units_sold, sum(i.Stock_On_Hand) as total_stock_available_in_inventory
from table1 as t1
join inventory as i
	on t1.Store_ID = i.Store_ID
group by t1.store_ID, t1.Store_Name, t1.avg_daily_units_sold
)
select Store_Name, round((total_stock_available_in_inventory / avg_daily_units_sold), 0) as 'How many days will the current inventory last?'
from table2; -- Based on the average daily sales from the last 30 days, the current inventory levels across toy stores are expected to last between 8 and 33 days, assuming no additional stock is ordered

-- Which store is generating the highest profit? Are stores opened long time ago more popular than newer ones?

select st.Store_Name, st.Store_Open_Date, sum((p.Product_Price - p.Product_Cost) * sa.units) as profit
from products as p
join sales as sa
	on p.Product_ID = sa.Product_ID
join stores as st
	on sa.Store_ID = st.Store_ID
group by st.Store_Name, st.Store_Open_Date
order by profit desc; -- 'Maven Toys Ciudad de Mexico 2’ is generating much more profit than the next most profitable store. There is no correlation between the age of the store and the profit it generates

-- Which products are selling the best? Is there a correlation between the total sales volume of a product and the profit made per unit sold?

with table1 as
(
select p.Product_Name, (p.Product_Price - p.Product_Cost) as profit, sum(sa.Units) as Total_Units_Sold
from products as p
join sales as sa
	on p.Product_ID = sa.Product_ID
group by p.Product_Name, profit
)
select Product_Name, profit, Total_Units_Sold, (profit * Total_Units_Sold) as Total_Profit
from table1
order by Total_Units_Sold desc; -- ColorBuds looks very good — it's the highest-selling product with a high profit per unit. Some other products with low profit margins are selling relatively poorly when we consider profit per unit