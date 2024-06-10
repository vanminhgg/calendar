WITH 
	QUOTENO AS (--
			SELECT
				QuoteNo
			FROM T_Quote_H
			WHERE 
				T_Quote_H.UpdateDate >= '2024/05/01' AND
				T_Quote_H.DeleteFlag <> 1 AND
				T_Quote_H.StatusFlag <> 9 AND
				T_Quote_H.IsNew = 0 AND
				T_Quote_H.QuoteNo <> ''
		UNION
			SELECT
				QuoteNo
			FROM T_Accept_H
			WHERE 
				T_Accept_H.UpdateDate >= '2024/05/01' AND T_Accept_H.QuoteNo <> ''
		UNION
			SELECT 
				QuoteNo
			FROM T_Shipping_H
			WHERE 
				T_Shipping_H.UpdateDate >= '2024/05/01' AND T_Shipping_H.QuoteNo <> ''
		UNION
			SELECT
				T_Accept_H.QuoteNo
			FROM T_Invoice_H LEFT JOIN T_Accept_H ON T_Invoice_H.AcceptNo = T_Accept_H.AcceptNo
			WHERE T_Accept_H.QuoteNo <> '' AND T_Invoice_H.UpdateDate >= '2024/05/01'),

	TS AS (
		SELECT 
			T_Shipping_H.QuoteNo,
			T_Serial.Memo 
		FROM T_Serial 
			LEFT JOIN T_Shipping_M ON T_Serial.ID = T_Shipping_M.InternalID
			LEFT JOIN T_Shipping_H ON T_Shipping_M.ID = T_Shipping_H.ID
		WHERE T_Serial.Memo IS NOT NULL AND T_Serial.Memo <> ''),

	MS AS (
		SELECT 
			MSC1.ID,
			MSC1.ParentID,
			MSC1.CategoryName,
			MSC2.CategoryName as ParentCategoryName
		FROM M_ServiceCategory as MSC1
			LEFT JOIN M_ServiceCategory as MSC2	ON MSC1.ParentID = MSC2.ID),

	TQH AS (
		SELECT
			T_Quote_H.ID,
			T_Quote_H.Projectname,
			T_Quote_H.QuoteNo,
			T_Quote_H.StatusFlag,
			T_Quote_H.IsNew,
			T_Quote_H.CustomerName1,
			T_Quote_H.UpdateDate,
			T_Quote_H.EstOrderDate,
			T_EndUser.EndUserCD as TQH_EndUserCD,
			T_EndUser.EndUserName1 as TQH_EndUserName,
			T_Quote_H.ServiceID,
			T_Quote_H.CreateDate,
			T_Quote_H.EstRevenueDate as TQH_EstRevenueDate,
			MS.ParentCategoryName as ServiceCategory,
			MS.CategoryName as Service
		FROM T_Quote_H
			LEFT JOIN T_EndUser	ON T_Quote_H.EndUserID = T_EndUser.ID
			LEFT JOIN MS ON T_Quote_H.ServiceID = MS.ID
		WHERE T_Quote_H.QuoteNo = 'KAM-2312-0001'),
	
	TQMS as (
		SELECT
			T_Quote_M_Sell.ID as TQMSID,
			SUM(CASE WHEN T_Quote_M_Sell.MRCFlag = 0 THEN T_Quote_M_Sell.SubTotalUSD ELSE 0 END ) as PriceNRC,
			SUM(CASE WHEN T_Quote_M_Sell.MRCFlag = 1 THEN T_Quote_M_Sell.SubTotalUSD ELSE 0 END ) as PriceMRC
		FROM T_Quote_M_Sell
		WHERE EXISTS(SELECT 1 FROM TQH WHERE TQH.ID = T_Quote_M_Sell.ID)
		GROUP BY T_Quote_M_Sell.ID
	),
	TQMC as (
		SELECT 
			T_Quote_M_Cost.ID as TQMCID,
			SUM(CASE WHEN T_Quote_M_Sell.MRCFlag  = 0 AND T_Quote_M_Cost.Maker <> 'KVN' THEN T_Quote_M_Cost.SubTotalUSD ELSE 0 END) as ExCostNRC,
			SUM(CASE WHEN T_Quote_M_Sell.MRCFlag =0 AND T_Quote_M_Cost.Maker = 'KVN' THEN T_Quote_M_Cost.SubTotalUSD ELSE 0 END) as InCostNRC,
			SUM(CASE WHEN T_Quote_M_Sell.MRCFlag  = 1 AND T_Quote_M_Cost.Maker <> 'KVN' THEN T_Quote_M_Cost.SubTotalUSD ELSE 0 END) as ExCostMRC,
			SUM(CASE WHEN T_Quote_M_Sell.MRCFlag =1 AND T_Quote_M_Cost.Maker = 'KVN' THEN T_Quote_M_Cost.SubTotalUSD ELSE 0 END) as InCostMRC
		FROM 
			T_Quote_M_Cost
			LEFT JOIN T_Quote_M_Sell ON T_Quote_M_Sell.ID = T_Quote_M_Cost.ID AND
										T_Quote_M_Sell.GridNo = T_Quote_M_Cost.GridNo
		WHERE EXISTS(SELECT 1 FROM TQH WHERE TQH.ID = T_Quote_M_Cost.ID)
		GROUP BY T_Quote_M_Cost.ID
	),
	
	QUOTATION AS (
		SELECT  
			*
		FROM 
			TQH 
			LEFT JOIN TQMS ON TQH.ID = TQMS.TQMSID
			LEFT JOIN TQMC ON TQH.ID = TQMCID),

	TAH AS (
		SELECT 
			T_Accept_H.ID,
			T_Accept_H.QuoteNo,
			T_Accept_H.AcceptNo,
			T_Accept_H.Projectname,
			T_Accept_H.CustomerName1,
			T_EndUser.EndUserCD as TAH_EndUserCD,
			T_EndUser.EndUserName1 as TAH_EndUserName,
			T_Accept_H.AcceptDate,
			T_Accept_H.EstFinishDate,
			T_Accept_H.EstRevenueDate as TAH_EstRevenueDate
		FROM T_Accept_H 
			LEFT JOIN T_EndUser ON T_Accept_H.EndUserID = T_EndUser.ID
		WHERE
			T_Accept_H.QuoteNo = 'KAM-2312-0001' AND
			T_Accept_H.DeleteFlag <> 1
	),

	TAMS as(
		SELECT
			T_Accept_M_Sell.ID as TAMSID,
			SUM(CASE WHEN T_Accept_M_Sell.MRCFlag = 0 THEN T_Accept_M_Sell.SubTotalUSD ELSE 0 END ) as PriceNRC,
			SUM(CASE WHEN T_Accept_M_Sell.MRCFlag = 1 THEN T_Accept_M_Sell.SubTotalUSD ELSE 0 END ) as PriceMRC,
			MIN(CASE WHEN T_Accept_M_Sell.MRCFlag = 1 THEN T_Accept_M_Sell.MRCDate ELSE '' END ) as ContractStartDate
		FROM
			T_Accept_M_Sell 
		WHERE EXISTS(SELECT 1 FROM TAH WHERE TAH.ID = T_Accept_M_Sell.ID)
		GROUP BY T_Accept_M_Sell.ID
	),

	TAMC as (
		SELECT
			T_Accept_M_Cost.ID TAMCID,
			SUM(CASE WHEN T_Accept_M_Sell.MRCFlag  = 0 AND T_Accept_M_Cost.Maker <> 'KVN' THEN T_Accept_M_Cost.SubTotalUSD ELSE 0 END) as ExCostNRC,
			SUM(CASE WHEN T_Accept_M_Sell.MRCFlag =0 AND T_Accept_M_Cost.Maker = 'KVN' THEN T_Accept_M_Cost.SubTotalUSD ELSE 0 END) as InCostNRC,
			SUM(CASE WHEN T_Accept_M_Sell.MRCFlag  = 1 AND T_Accept_M_Cost.Maker <> 'KVN' THEN T_Accept_M_Cost.SubTotalUSD ELSE 0 END) as ExCostMRC,
			SUM(CASE WHEN T_Accept_M_Sell.MRCFlag =1 AND T_Accept_M_Cost.Maker = 'KVN' THEN T_Accept_M_Cost.SubTotalUSD ELSE 0 END) as InCostMRC
		FROM 
			T_Accept_M_Cost
			LEFT JOIN T_Accept_M_Sell ON T_Accept_M_Sell.ID = T_Accept_M_Cost.ID AND
										T_Accept_M_Sell.GridNo = T_Accept_M_Cost.GridNo
		WHERE EXISTS(SELECT 1 FROM TAH WHERE TAH.ID = T_Accept_M_Cost.ID)
		GROUP BY T_Accept_M_Cost.ID
	),

	ACCEPTANCE AS (
		SELECT 
			*
		FROM 
			TAH 
			LEFT JOIN TAMS ON TAH.ID = TAMS.TAMSID
			LEFT JOIN TAMC ON TAH.ID = TAMC.TAMCID),

	CR_MRCNO as ( -- get renewal QuoteNo
		SELECT
			QUOTATION.QuoteNo,
			(CASE WHEN TS.QuoteNo IS NULL THEN QUOTATION.QuoteNo ELSE TS.QuoteNo END) as CrPriceQuoteNo
		FROM 
			QUOTATION
			LEFT JOIN TS ON QUOTATION.QuoteNo = TS.Memo
		WHERE QUOTATION.QuoteNo = 'KAM-2312-0001'
	),

	CR_PRICEMRC as ( -- GET CurrentPriceMRC From T_Accept_M_Sell
		SELECT 
			CR_MRCNO.QuoteNo,
			SUM(CASE WHEN T_Accept_M_Sell.MRCFlag = 1 THEN T_Accept_M_Sell.SubTotalUSD ELSE 0 END ) as CurrentPriceMRC
		FROM
			T_Accept_M_Sell 
			LEFT JOIN T_Accept_H ON T_Accept_M_Sell.ID = T_Accept_H.ID AND T_Accept_H.DeleteFlag <> 1
			LEFT JOIN CR_MRCNO ON T_Accept_H.QuoteNo = CR_MRCNO.CrPriceQuoteNo
		GROUP BY CR_MRCNO.QuoteNo, CR_MRCNO.CrPriceQuoteNo
	),

	CR_COSTMRC as (-- GET CurrentCostMRC FROM T_Accept_M_Cost
		SELECT
			CR_MRCNO.QuoteNo,
			SUM(CASE WHEN T_Accept_M_Sell.MRCFlag = 1 THEN T_Accept_M_Cost.SubTotalUSD ELSE 0 END ) as CurrentCostMRC
		FROM
			T_Accept_M_Cost
			LEFT JOIN T_Accept_M_Sell ON T_Accept_M_Cost.ID = T_Accept_M_Sell.ID AND
										 T_Accept_M_Cost.GridNo = T_Accept_M_Sell.GridNo
			LEFT JOIN T_Accept_H ON T_Accept_M_Cost.ID = T_Accept_H.ID AND T_Accept_H.DeleteFlag <> 1	
			LEFT JOIN CR_MRCNO ON T_Accept_H.QuoteNo = CR_MRCNO.CrPriceQuoteNo
		GROUP BY CR_MRCNO.QuoteNo, T_Accept_H.QuoteNo
	),	

	TA_QUANTITY AS ( -- Acceptance Quantity
		SELECT
			T_Accept_H.AcceptNo,
			SUM(T_Accept_M_Sell.Quantity) as TotalQuantity	
		FROM T_Accept_H LEFT JOIN T_Accept_M_Sell ON T_Accept_H.ID = T_Accept_M_Sell.ID
		WHERE T_Accept_H.QuoteNo = 'KAM-2312-0001'
		GROUP BY T_Accept_H.AcceptNo),

	SHIPPING AS ( -- Get shippingFlag and CompletionDate
		SELECT
		T_Shipping_H.AcceptNo,
		 (CASE WHEN SUM(T_Shipping_M.Quantity) = TA_QUANTITY.TotalQuantity AND NOT EXISTS(SELECT * FROM T_Shipping_H TSH WHERE TSH.AcceptNo = T_Shipping_H.AcceptNo AND TSH.FinishFlag = 0 AND TSH.DeleteFlag <> 1) THEN '1' ELSE '0' END) as ShippingFlag,
		 MAX(T_Shipping_H.UpdateDate) as ComfirmDate
		FROM T_Shipping_M 
			LEFT JOIN T_Shipping_H ON T_Shipping_M.ID = T_Shipping_H.ID
			LEFT JOIN TA_QUANTITY ON T_Shipping_H.AcceptNo = TA_QUANTITY.AcceptNo
		WHERE T_Shipping_H.QuoteNo = 'KAM-2312-0001' AND T_Shipping_H.DeleteFlag <> 1
		GROUP BY T_Shipping_H.AcceptNo, TA_QUANTITY.TotalQuantity),

	INVOICE AS (
		SELECT 
			T_Invoice_H.AcceptNo,
			MiN(InvoiceDate) as InvoiceDate   
		FROM T_Invoice_H
		WHERE EXISTS(SELECT * FROM TAH WHERE TAH.AcceptNo = T_Invoice_H.AcceptNo) AND T_Invoice_H.DeleteFlag <> 1 -- add
		GROUP BY T_Invoice_H.AcceptNo)
			
SELECT 
    'KVN' as GroupCompanyCode,
    ISNULL((CASE WHEN QUOTATION.StatusFlag<> 1 AND QUOTATION.IsNew = 0 THEN QUOTATION.Projectname ELSE ACCEPTANCE.Projectname END), '') as OpportunityName,
    ISNULL((CASE WHEN QUOTATION.StatusFlag<> 1 AND QUOTATION.IsNew = 0 THEN QUOTATION.CustomerName1 ELSE ACCEPTANCE.CustomerName1 END),'') as LocalAccountName,
    QUOTATION.StatusFlag,
    ISNULL((CASE WHEN QUOTATION.StatusFlag = 0 THEN QUOTATION.UpdateDate
            WHEN QUOTATION.StatusFlag = 1 THEN ACCEPTANCE.AcceptDate
            ELSE QUOTATION.EstOrderDate END),'') as CloseDate,
    (CASE WHEN EXISTS(SELECT * FROM T_Quote_M_Sell WHERE T_Quote_M_Sell.MRCRenew = 1 AND QUOTATION.ID = T_Quote_M_Sell.ID) AND QUOTATION.StatusFlag = 0 THEN 'Cancellation'
            WHEN EXISTS(SELECT * FROM T_Quote_M_Sell WHERE T_Quote_M_Sell.MRCRenew = 1 AND QUOTATION.ID = T_Quote_M_Sell.ID) AND QUOTATION.StatusFlag<> 0 THEN 'Modification ' ELSE 'New' END) as OpportunityType, 
    'USD' as Currency,
    ISNULL((CASE WHEN QUOTATION.StatusFlag<> 1 AND QUOTATION.IsNew = 0 THEN QUOTATION.PriceNRC ELSE ACCEPTANCE.PriceNRC END ),0) as PriceNRC,
    ISNULL((CASE WHEN QUOTATION.StatusFlag<> 1 AND QUOTATION.IsNew = 0 THEN QUOTATION.PriceMRC ELSE ACCEPTANCE.PriceMRC END ),0) as PriceMRC,
    ISNULL(CR_PRICEMRC.CurrentPriceMRC,0) as CurrentPriceMRC,
    QUOTATION.QuoteNo as LocalOppNo,
    '' as LeadSupport,
    ISNULL((CASE WHEN QUOTATION.StatusFlag<> 1 AND QUOTATION.IsNew = 0 THEN QUOTATION.TQH_EndUserCD ELSE ACCEPTANCE.TAH_EndUserCD END),'') as LocalEnduserId,
    ISNULL((CASE WHEN QUOTATION.StatusFlag<> 1 AND QUOTATION.IsNew = 0 THEN QUOTATION.TQH_EndUserName ELSE ACCEPTANCE.TAH_EndUserName END),'') as LocalEnduserName,
    ISNULL(QUOTATION.ServiceCategory,'') as ServiceCategory,
    QUOTATION.Service,
    ISNULL(QUOTATION.CreateDate,'') as FirstEntryDate,
    ISNULL((CASE WHEN QUOTATION.StatusFlag = 0 THEN ''
          WHEN QUOTATION.StatusFlag = 1 THEN ACCEPTANCE.AcceptDate
          ELSE QUOTATION.EstOrderDate END),'') as OrderDate,
    ISNULL((CASE WHEN SHIPPING.ShippingFlag = 1  THEN SHIPPING.ComfirmDate ELSE ACCEPTANCE.EstFinishDate END),'') as CompletionDate,
    ISNULL((CASE WHEN QUOTATION.StatusFlag<> 1 THEN QUOTATION.TQH_EstRevenueDate
            WHEN QUOTATION.StatusFlag = 1 AND INVOICE.InvoiceDate IS NOT NULL THEN INVOICE.InvoiceDate
            ELSE ACCEPTANCE.TAH_EstRevenueDate END),'') as BillingDate,
    (CASE WHEN QUOTATION.StatusFlag = 1  OR QUOTATION.StatusFlag = 2 THEN 1 ELSE 0 END ) as Commitment,
    (CASE WHEN INVOICE.InvoiceDate IS NOT NULL THEN 1 ELSE 0 END) as InvoiceIssued,
    ISNULL((CASE WHEN QUOTATION.StatusFlag<> 1 THEN QUOTATION.ExCostNRC ELSE ACCEPTANCE.ExCostNRC END),0) as ExCostNRC,
    ISNULL((CASE WHEN QUOTATION.StatusFlag<> 1 THEN QUOTATION.InCostNRC ELSE ACCEPTANCE.InCostNRC END),0) as InCostNRC,
    ISNULL((CASE WHEN QUOTATION.StatusFlag<> 1 THEN QUOTATION.ExCostMRC ELSE ACCEPTANCE.ExCostMRC END),0) as ExCosMRC,
    ISNULL(CR_COSTMRC.CurrentCostMRC,0) as CurrentCostMRC,
    ISNULL((CASE WHEN QUOTATION.StatusFlag<> 1 THEN QUOTATION.InCostMRC ELSE ACCEPTANCE.InCostMRC END),0) as InCostMRC,
    ISNULL((CASE WHEN QUOTATION.StatusFlag = 1  THEN ACCEPTANCE.ContractStartDate ELSE '' END),'') as ContractStartDate
FROM 
	QUOTATION 
	LEFT JOIN ACCEPTANCE ON QUOTATION.QuoteNo = ACCEPTANCE.QuoteNo
	LEFT JOIN SHIPPING ON ACCEPTANCE.AcceptNo = SHIPPING.AcceptNo
	LEFT JOIN INVOICE ON ACCEPTANCE.AcceptNo = INVOICE.AcceptNo
	LEFT JOIN CR_PRICEMRC ON QUOTATION.QuoteNo = CR_PRICEMRC.QuoteNo
	LEFT JOIN CR_COSTMRC ON QUOTATION.QuoteNo = CR_COSTMRC.QuoteNo
