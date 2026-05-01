-- =====================================================
-- Portfolio Analytics: Risk & Performance SQL Queries
-- =====================================================
-- Description:
-- This file contains SQL queries used for portfolio analysis,
-- including performance, benchmark comparison, and risk metrics.
-- =====================================================


-- =====================================================
-- 1. DATABASE OVERVIEW
-- Purpose: List all tables in the database
-- =====================================================
SELECT name
FROM sqlite_master
WHERE type = 'table';


-- =====================================================
-- 2. DATA VALIDATION
-- Purpose: Check row counts for all major tables
-- =====================================================
SELECT 'dim_asset' AS table_name, COUNT(*) AS row_count FROM dim_asset
UNION ALL
SELECT 'fact_asset_prices', COUNT(*) FROM fact_asset_prices
UNION ALL
SELECT 'fact_asset_returns', COUNT(*) FROM fact_asset_returns
UNION ALL
SELECT 'portfolio_weights', COUNT(*) FROM portfolio_weights
UNION ALL
SELECT 'fact_portfolio_returns', COUNT(*) FROM fact_portfolio_returns
UNION ALL
SELECT 'monthly_portfolio_returns', COUNT(*) FROM monthly_portfolio_returns;


-- =====================================================
-- 3. PORTFOLIO ALLOCATION ANALYSIS
-- Purpose: View asset allocation by ticker, sector, and class
-- =====================================================
SELECT
    w.ticker,
    a.asset_name,
    a.asset_class,
    a.sector,
    ROUND(w.weight * 100, 2) AS portfolio_weight_pct
FROM portfolio_weights w
JOIN dim_asset a
    ON w.ticker = a.ticker
ORDER BY w.weight DESC;


-- =====================================================
-- 4. DAILY PORTFOLIO PERFORMANCE
-- Purpose: Analyze daily returns and cumulative growth
-- =====================================================
SELECT
    return_date,
    ROUND(portfolio_daily_return * 100, 4) AS daily_return_pct,
    ROUND(cumulative_return * 100, 2) AS cumulative_return_pct
FROM fact_portfolio_returns
ORDER BY return_date;


-- =====================================================
-- 5. MONTHLY PERFORMANCE TREND
-- Purpose: Evaluate monthly aggregated returns
-- =====================================================
SELECT
    month,
    ROUND(monthly_return * 100, 2) AS monthly_return_pct
FROM monthly_portfolio_returns
ORDER BY month;


-- =====================================================
-- 6. PORTFOLIO VS BENCHMARK (DAILY RETURNS)
-- Purpose: Compare daily returns against S&P 500 (SPY)
-- =====================================================
SELECT
    p.return_date,
    p.portfolio_daily_return,
    b.daily_return AS benchmark_return
FROM fact_portfolio_returns p
JOIN fact_asset_returns b
    ON p.return_date = b.return_date
WHERE b.ticker = 'SPY'
ORDER BY p.return_date;


-- =====================================================
-- 7. PORTFOLIO VS BENCHMARK (CUMULATIVE RETURNS)
-- Purpose: Compare compounded returns over time
-- =====================================================
SELECT
    p.return_date,
    ROUND(p.cumulative_return * 100, 2) AS portfolio_cum_return_pct,
    ROUND(
        (EXP(SUM(LOG(1 + b.daily_return)) OVER (ORDER BY b.return_date)) - 1) * 100,
        2
    ) AS benchmark_cum_return_pct
FROM fact_portfolio_returns p
JOIN fact_asset_returns b
    ON p.return_date = b.return_date
WHERE b.ticker = 'SPY'
ORDER BY p.return_date;


-- =====================================================
-- 8. PORTFOLIO PERFORMANCE METRICS
-- Purpose: Calculate annualized return, volatility, and Sharpe ratio
-- =====================================================
SELECT
    ROUND(AVG(portfolio_daily_return) * 252 * 100, 2) AS annualized_return_pct,
    ROUND(
        SQRT(
            AVG(portfolio_daily_return * portfolio_daily_return)
            - AVG(portfolio_daily_return) * AVG(portfolio_daily_return)
        ) * SQRT(252) * 100,
        2
    ) AS annualized_volatility_pct,
    ROUND(
        (AVG(portfolio_daily_return) * 252) /
        (
            SQRT(
                AVG(portfolio_daily_return * portfolio_daily_return)
                - AVG(portfolio_daily_return) * AVG(portfolio_daily_return)
            ) * SQRT(252)
        ),
        2
    ) AS sharpe_ratio
FROM fact_portfolio_returns;


-- =====================================================
-- 9. MAXIMUM DRAWDOWN ANALYSIS
-- Purpose: Identify worst peak-to-trough decline
-- =====================================================
WITH cumulative AS (
    SELECT
        return_date,
        cumulative_return,
        MAX(cumulative_return) OVER (
            ORDER BY return_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_max
    FROM fact_portfolio_returns
),
drawdown AS (
    SELECT
        return_date,
        cumulative_return,
        running_max,
        (cumulative_return - running_max) / (1 + running_max) AS drawdown
    FROM cumulative
)
SELECT
    return_date,
    ROUND(drawdown * 100, 2) AS drawdown_pct
FROM drawdown
ORDER BY drawdown ASC
LIMIT 1;


-- =====================================================
-- 10. ROLLING VOLATILITY ANALYSIS
-- Purpose: Measure time-varying risk (30-day window)
-- =====================================================
SELECT
    return_date,
    ROUND(
        SQRT(
            AVG(portfolio_daily_return * portfolio_daily_return) OVER (
                ORDER BY return_date
                ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
            )
            -
            POWER(
                AVG(portfolio_daily_return) OVER (
                    ORDER BY return_date
                    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
                ), 2
            )
        ) * SQRT(252) * 100,
        2
    ) AS rolling_30d_volatility_pct
FROM fact_portfolio_returns
ORDER BY return_date;


-- =====================================================
-- 11. ASSET CONTRIBUTION TO PORTFOLIO RETURN
-- Purpose: Estimate how much each holding contributes to portfolio performance
-- =====================================================
SELECT
    r.ticker,
    a.asset_name,
    a.sector,
    ROUND(w.weight * 100, 2) AS portfolio_weight_pct,
    ROUND(AVG(r.daily_return) * 252 * 100, 2) AS annualized_asset_return_pct,
    ROUND((AVG(r.daily_return) * 252 * w.weight) * 100, 2) AS weighted_return_contribution_pct
FROM fact_asset_returns r
JOIN portfolio_weights w
    ON r.ticker = w.ticker
JOIN dim_asset a
    ON r.ticker = a.ticker
GROUP BY
    r.ticker,
    a.asset_name,
    a.sector,
    w.weight
ORDER BY weighted_return_contribution_pct DESC;


