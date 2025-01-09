--Run this before you execute your SQL scripts
CREATE SCHEMA dannys_diner;
SET search_path = dannys_diner;

--Question 1. What is the total amount each customer spent at the restaurant?

select s.customer_id,
       sum(m.price) as total_amount
from menu m join sales s on s.product_id=m.product_id
group by customer_id
order by total_amount desc;


--Question 2. How many days has each customer visited the restaurant?

select customer_id,
       count(distinct(order_date)) as total_days
from sales
group by customer_id
order by total_days desc;


--Question 3. What was the first item from the menu purchased by each customer?

with first_item_purchased as
(
select s.customer_id,m.product_name,s.order_date,
       dense_rank () over(partition by s.customer_id order by s.order_date) as drk
from menu m join sales s on m.product_id=s.product_id 
)
select distinct customer_id,
       product_name 
from first_item_purchased 
where drk=1;


--Question 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

select m.product_name,
       count(s.product_id) as item_purchase_cnt
from menu m join sales s on m.product_id=s.product_id
group by product_name 
order by item_purchase_cnt desc limit 1;


--Question 5. Which item was the most popular for each customer?

with item_purchase_count as 
(
select s.customer_id,
	   m.product_name,
	   count(s.product_id) as item_cnt
from menu m join sales s on m.product_id=s.product_id
group by s.customer_id,m.product_name
),

most_popular_item as 
(
select customer_id,product_name,item_cnt,
       dense_rank() over(partition by customer_id order by item_cnt desc) as drk
from item_purchase_count
)
select customer_id,
       product_name,
	   item_cnt 
from most_popular_item 
where drk=1;


--Question 6. Which item was purchased first by the customer after they became a member?

with purchased_after_member as 
(
select s.customer_id,s.product_id,
       dense_rank() over(partition by s.customer_id order by s.order_date) as drk
from sales s join members mb on s.customer_id=mb.customer_id and s.order_date>mb.join_date
)
select pam.customer_id,
       m.product_name
from purchased_after_member pam join menu m on pam.product_id=m.product_id
where drk=1
order by pam.customer_id;


--Question 7. Which item was purchased just before the customer became a member?

with purchased_before_member as
(
select s.customer_id,
	   s.product_id,
	   s.order_date,
       dense_rank() over(partition by s.customer_id order by s.order_date desc) as drk
from sales s join members mb on s.customer_id=mb.customer_id and s.order_date<mb.join_date
)
select pbm.customer_id,
       m.product_name
from purchased_before_member pbm join menu m on pbm.product_id=m.product_id
where drk=1
order by pbm.customer_id;


--Question 8. What is the total items and amount spent for each member before they became a member?


select s.customer_id,
       count(s.product_id) as total_items,
	   sum(m.price) as total_sales
from sales s join members mb on s.customer_id=mb.customer_id and s.order_date<mb.join_date
join menu m on s.product_id=m.product_id
group by s.customer_id
order by s.customer_id;


--Question 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?


with points as 
(
select product_id,
	   case when product_id=1 then price*20
	   else price*10
	   end as points
from menu
)
select s.customer_id,
       sum(p.points) as total_points
from sales s join points p on s.product_id=p.product_id
group by s.customer_id
order by s.customer_id;


/**Question 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi
- how many points do customer A and B have at the end of January?**/


with member_offer as 
(
select customer_id,
       join_date,
	   join_date+6 as offer_valid_date,
	   DATE_TRUNC('month', '2021-01-31'::DATE)+ interval '1 month' - interval '1 day' as end_date
from members
)
select s.customer_id,
	   sum(case 
		       when m.product_name='sushi' then m.price*20
		       when s.order_date between mo.join_date and mo.offer_valid_date then m.price*20
		       else m.price*10 end) as points
from sales s join member_offer mo on s.customer_id=mo.customer_id and s.order_date<=mo.end_date 
join menu m on s.product_id=m.product_id
group by s.customer_id;


--Bonus Questions
/**Question 1. Join All The Things
Recreate the table with: customer_id, order_date, product_name, price, member (Y/N)**/


select s.customer_id,
       s.order_date,
	   m.product_name,
	   m.price,
	   case 
	        when s.order_date>=mb.join_date then 'Y'
			else 'N' end as member
from sales s join menu m on s.product_id=m.product_id
left join members mb on s.customer_id=mb.customer_id
order by s.customer_id,s.order_date;


/**Question 2. Rank All The Things
Danny also requires further information about the ranking of customer products, but he purposely does not need the ranking for non-member purchases 
so he expects null ranking values for the records when customers are not yet part of the loyalty program.**/


with products_ranking as
(
select s.customer_id,
       s.order_date,
	   m.product_name,
	   m.price,
	   case 
	        when s.order_date>=mb.join_date then 'Y'
			else 'N' end as member
from sales s join menu m on s.product_id=m.product_id
left join members mb on s.customer_id=mb.customer_id
order by s.customer_id,s.order_date
)
select customer_id,
       order_date,
	   product_name,
	   price,
	   member,
	   case 
	        when member ='N' then NULL
			else dense_rank() over(partition by customer_id,member order by order_date) end as ranking
from products_ranking;
