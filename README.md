# retail-replenishment-analysis
SQL Server + Excel + Power BI analysis of 1M real retail transactions.
       # Retail Product Performance & Replenishment Analysis
A SQL Server + Excel + Power BI project on real retail data (over 1 million rows). I wanted to find out which products matter most, how much cancellations cost, and which products to restock before the autumn peak.

![Overview](<img width="1920" height="1010" alt="Overview_pbi_Screenshot " src="https://github.com/user-attachments/assets/3deef986-21b9-4071-831b-6138cd7652a7" />
)

## Data
Online Retail II from the UCI Machine Learning Repository (Chen, D., 2019), licence CC BY 4.0:
[Online Retail II dataset (UCI Machine Learning Repository)](https://archive.ics.uci.edu/dataset/502/online+retail+ii)
I haven't uploaded the file because it's too big, so please download it from the link. The data has no stock levels or supplier lead times, so my restock list is based on demand only. "Revenue" here means quantity × price on normal sales, and cancellations are counted separately.

## Cleaning
- 243,007 rows had no customer ID. I kept them for product analysis and left them out when counting customers.
- Removed 34,335 duplicate rows
- Separated 8,292 cancelled invoices
- Removed non-product codes like postage and fees
- Merged product codes that only differed by upper or lower case (4,877 became 4,707 products)

That left 1,003,213 sales rows and £19.64M of revenue.

## What I did
Sales overview, cancellations, ABC analysis (which products make most of the revenue), seasonality, a restock priority list, an Excel reorder planner and a Power BI dashboard.

## What I found
- 21.9% of products (1,030 of 4,707) make 80% of revenue
- September to November brings about 37% of the year's revenue
- 15.5% of invoices were cancellations, but only 3.7% of the sales value
- 400 of the top products sell at least 1.5x faster in Sep to Nov, and 239 of them have very uneven demand, so they need extra safety stock

## Power BI dashboard
Three pages: Overview, Products (ABC) and Seasonality & Restock. There are slicers for month, country and ABC class.

![Products](<img width="1920" height="1024" alt="Products(ABC)_pbi_Screenshot " src="https://github.com/user-attachments/assets/6340e6df-7b65-4524-9c9d-b89074a79fe1" />
)
![Seasonality](<img width="1920" height="1019" alt="Seasonality   restock_pbi_Screenshot " src="https://github.com/user-attachments/assets/d685f9c3-c3b6-4411-a035-ecaba9969b2c" />
)

## Excel planner
It takes the 400 priority products and works out safety stock, reorder point and how much to order before the peak. The lead time (14 days), service level (95%) and days of cover (30) are assumptions I picked, not numbers from the data, and you can change them.

## Folders
`sql` for the scripts, `excel` for the planner, `powerbi` for the report, `images` for the screenshots.

## How to run
1. Download the data, rename the columns as in `R00`, and save it as `C:\Retail\online_retail_II.csv`.
2. In SQL Server Management Studio, run `R00` to `R06` in order.
3. Open the `.pbix` in Power BI Desktop. It reads from a local database called `RetailAnalysis`, so if your server name is different, change it under Transform data > Data source settings.

## Limitations
- Because there's no stock data, the planner is a what-if tool and not a forecast
- Revenue is gross. Two big orders were cancelled later but still count as sales, which makes two products look bigger than they are
- The peak pattern comes from only two autumns
