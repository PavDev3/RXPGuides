local addonName, addon = ...

if addon.gameVersion > 20000 then return end

local fmt, tinsert, ipairs, pairs, next, type, wipe, tonumber, strlower =
    string.format, table.insert, ipairs, pairs, next, type, wipe, tonumber,
    strlower

local CanSendAuctionQuery, QueryAuctionItems, SetSelectedAuctionItem =
    _G.CanSendAuctionQuery, _G.QueryAuctionItems, _G.SetSelectedAuctionItem
local GetNumAuctionItems, GetAuctionItemLink, GetAuctionItemInfo =
    _G.GetNumAuctionItems, _G.GetAuctionItemLink, _G.GetAuctionItemInfo

local AuctionFilterButtons = {["Consumable"] = 4, ["Trade Goods"] = 5}

addon.auctionHouse = addon:NewModule("AuctionHouse", "AceEvent-3.0")

local session = {
    isInitialized = false,

    -- Cannot cache to RXPCData, because comparisons are mutable and embedded in weighting
    scanData = {},

    windowOpen = false,
    scanPage = 0,
    scanResults = 0,
    scanType = AuctionFilterButtons["Consumable"],

    selectedRow = nil
}

function addon.auctionHouse:Setup()
    if session.isInitialized then return end

    self:RegisterEvent("AUCTION_HOUSE_SHOW")
    self:RegisterEvent("AUCTION_HOUSE_CLOSED")

    self:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")

    session.isInitialized = true
    RXPD2 = session
end

function addon.auctionHouse:AUCTION_HOUSE_SHOW()
    session.windowOpen = true

    -- self:CreateEmbeddedGui()
end

function addon.auctionHouse:AUCTION_HOUSE_CLOSED()

    -- Reset session
    session.windowOpen = false
    session.sentQuery = false
    session.scanPage = 0
    session.scanResults = 0
    session.scanType = AuctionFilterButtons["Consumable"]
end

-- Helper function for scanning.xml RXP_IU_AH_BuyButton:OnClick
function addon.auctionHouse:SearchForSelectedItem()
    return self:SearchForBuyoutItem(session.selectedRow.nodeData)
end

local function getNameFromLink(itemLink)
    return string.match(itemLink, "h%[(.*)%]|h")
end

-- TODO generalize for itemUpgrades.AH use
function addon.auctionHouse:SearchForBuyoutItem(nodeData)
    if not (nodeData.Name and nodeData.ItemLevel) then return end

    -- print("SearchForBuyoutItem", nodeData.Name)

    if _G.BrowseResetButton then _G.BrowseResetButton:Click() end

    _G.BrowseName:SetText(getNameFromLink(nodeData.ItemLink))
    _G.BrowseMinLevel:SetText(nodeData.ItemLevel)
    _G.BrowseMaxLevel:SetText(nodeData.ItemLevel)

    -- Sort to make item very likely on first page
    -- sortTable, sortColumn, oppositeOrder
    _G.AuctionFrame_SetSort("list", "bid", false);
    _G.AuctionFrameTab1:Click()

    -- Pre-populates UI, so let user retry if server overloaded
    if CanSendAuctionQuery() then _G.AuctionFrameBrowse_Search() end

    -- TODO scan page handling
end

-- TODO generalize for itemUpgrades.AH use
function addon.auctionHouse:FindItemOnPage(nodeData)
    if not nodeData then
        -- print("FindItemOnPage error: selectedRow nil")
        return
    end
    if not (nodeData.ItemID and nodeData.ItemLink and nodeData.BuyoutMoney) then
        return
    end

    local resultCount = GetNumAuctionItems("list")

    if resultCount == 0 then
        -- print("FindItemOnPage error: no results")
        return
    end

    -- print("FindItemOnPage", nodeData.Name, resultCount)
    local itemLink
    local buyoutPrice, itemID

    for i = 1, resultCount do
        itemLink = GetAuctionItemLink("list", i)

        -- name, texture, count, quality, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo(type, index)
        _, _, _, _, _, _, _, _, _, buyoutPrice, _, _, _, _, _, _, itemID, _ =
            GetAuctionItemInfo("list", i)
        -- print("Evaluating", i, itemLink, buyoutPrice)

        if itemID == nodeData.ItemID and itemLink == nodeData.ItemLink and
            buyoutPrice == nodeData.BuyoutMoney then
            SetSelectedAuctionItem("list", i)
            return i
        end

    end

    -- Shouldn't need to handle Pagination, sorted by cheapest which is the goal
    --  May hit issues if 10+ bid-only
    -- Rely on BrowseNextPageButton:Click() :IsEnabled for easy pagination handling
end

-- Triggers each time the scroll panel is updated
-- Scrolling, initial population
-- Blizzard's standard auction house view overcomes this problem by reacting to AUCTION_ITEM_LIST_UPDATE and re-querying the items.
function addon.auctionHouse:AUCTION_ITEM_LIST_UPDATE()
    -- TODO prevent overwriting/blocking full scan
    if session.selectedRow and session.selectedRow.nodeData then
        self:FindItemOnPage(session.selectedRow.nodeData)
    end

    if not session.sentQuery then return end

    local resultCount, totalAuctions = GetNumAuctionItems("list")
    print("AUCTION_ITEM_LIST_UPDATE", resultCount, totalAuctions)

    -- session.displayFrame.scanButton:SetText(_G.SEARCHING)

    -- TODO generalize for itemUpgrades
    if resultCount == 0 or totalAuctions == 0 then
        session.sentQuery = false
        session.scanPage = 0 -- TODO show scanPage on UI

        -- TODO generalize
        if session.scanType == AuctionFilterButtons["Consumable"] then
            session.scanType = AuctionFilterButtons["Trade Goods"] -- weapons
            self:Scan()
        else
            session.scanType = AuctionFilterButtons["Consumable"]
            print("Done")
            -- self:Analyze()
            -- session.displayFrame.scanButton:SetText(_G.SEARCH)
            -- self:DisplayEmbeddedResults()
        end

        return
    end

    local itemLink
    local name, texture, count, level, buyoutPrice, itemID

    for i = 1, resultCount do
        itemLink = GetAuctionItemLink("list", i)

        -- name, texture, count, quality, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo(type, index)
        name, texture, count, _, _, level, _, _, _, buyoutPrice, _, _, _, _, _, _, itemID, _ =
            GetAuctionItemInfo("list", i)

        -- TODO if not hasAllInfo
        if session.scanData[itemLink] then
            if buyoutPrice < session.scanData[itemLink].lowestPrice then
                session.scanData[itemLink].lowestPrice = buyoutPrice
            elseif buyoutPrice == session.scanData[itemLink].lowestPrice then
                session.scanData[itemLink].count =
                    session.scanData[itemLink].count + count
            end
        else
            session.scanData[itemLink] = {
                name = name,
                lowestPrice = buyoutPrice,
                itemID = itemID,
                level = level,
                scanType = session.scanType, -- TODO propagate scanType for proper filters
                itemIcon = texture,
                count = count
            }
        end

        -- print("scan", itemLink, itemID, hasAllInfo, buyoutPrice)
    end

    session.sentQuery = false

    session.scanPage = session.scanPage + 1

    session.scanResults = session.scanResults + resultCount

    self:Scan()
end

function addon.auctionHouse:Scan()
    -- Prevent double calls
    if session.sentQuery then return end
    if not AuctionCategories then return end -- AH frame isn't loaded yet

    -- TODO use better queueing
    -- TODO abort on multiple retries
    if not CanSendAuctionQuery() then
        -- print("addon.auctionHouse:Scan() - queued", session.scanPage, session.scanType)

        -- TODO check if BrowseSearchButton is re-enabled
        C_Timer.After(0.35, function() self:Scan() end)
        return
    end
    -- print("addon.auctionHouse:Scan()", session.scanType, session.scanPage)

    -- TODO reset usable = true

    session.sentQuery = true

    -- text, minLevel, maxLevel, page, usable, rarity, getAll, exactMatch, filterData
    QueryAuctionItems("", nil, nil, session.scanPage, true,
                      Enum.ItemQuality.Standard, false, false,
                      AuctionCategories[session.scanType].filters)
end
