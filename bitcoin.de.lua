-- Inofficial bitcoin.de Extension (https://www.bitcoin.de) for MoneyMoney
-- Fetches balances from bitcoin.de and returns them as securities
--
-- Username: bitcoin.de API-Key
-- Password: bitcoin.de API-Secret
--
-- Ensure to create a new bitcoin.de API-Key for MoneyMoney and
-- enable "showAccountInfo" and "showRates"
--
-- MIT License
--
-- Copyright (c) 2018 Robert Gering
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

WebBanking {
  version = 1.1,
  country = "de",
  description = string.format(MM.localizeText("Fetch balances from %s and list them as securities"), "bitcoin.de"),
  services = { "bitcoin.de" },
}

-- State
local apiKey
local apiSecret
local nonce = MM.time() * 10
local balances
local credits = 10
local rates = {}

-- Api Constants
local apiBase = "https://api.bitcoin.de/v2/"
local market = "bitcoin.de"
local currency = "EUR"
local currencyNames = {
  BTC = "Bitcoin",
  BCH = "Bitcoin Cash",
  BTG = "Bitcoin Gold",
  BSV = "Bitcoin SV",
  LTC = "Litecoin",
  ETH = "Ethereum",
  IOT = "IOTA",
  XRP = "Ripple",
  ZEC = "ZCash",
  ETC = "Ethereum Classic",
  XMR = "Monero",
  DSH = "Dash",
  NEO = "Neo"
}

-- Extension Interface Implementaion

function SupportsBank(protocol, bankCode)
  return protocol == ProtocolWebBanking and bankCode == "bitcoin.de"
end

function InitializeSession(protocol, bankCode, username, username2, password, username3)
  MM.printStatus("Login (API-Key & API-Secret)")
  apiKey = username
  apiSecret = password

  balances = queryBalances()
  if balances == nil then
    return LoginFailed
  end

  queryRates(balances)
end

function ListAccounts(knownAccounts)
  local account = {
    name = "bitcoin.de",
    accountNumber = "Wallet",
    currency = "EUR",
    portfolio = true,
    type = AccountTypePortfolio
  }

  return {account}
end

function RefreshAccount(account, since)
  local s = {}

  for index, values in pairs(balances) do
    local currencyName = index:upper()
    local shares = tonumber(values["total_amount"])
    local pair = index:lower() .. currency:lower()
    local price = rates[pair]

    if price ~= nil and shares > 0 then
      s[#s+1] = {
        name = currencyNames[currencyName] .. " (" .. currencyName .. ")",
        market = market,
        currency = nil,
        quantity = shares,
        price = price
      }
    end
  end

  return {securities = s}
end

function EndSession()
end

-- bitcoin.de API Implementation --

function queryBalances()
  local json = query("account", nil)
  return json:dictionary()["data"]["balances"]
end

function queryRates()
  for index, values in pairs(balances) do
    pair = index:lower() .. currency:lower()
    rates[pair] = queryRate(pair)
  end
end

function queryRate(pair)
  print("query rate: " .. pair)
  local params = {}
  params["trading_pair"] = pair
  local json = query("rates", params)
  return tonumber(json:dictionary()["rates"]["rate_weighted"])
end

function query(method, params)
  if credits < 4 then
    MM.sleep(4 - credits)
  end

  local url = apiBase .. method
  if params ~= nil then
    url = url .. "?"
    for index, value in pairs(params) do
      url = url .. index .. "=" .. value
    end
  end

  local nonce = nextApiNonce()
  local signature = signature(nonce, "GET", url)

  local headers = {}
  headers["X-API-KEY"] = apiKey
  headers["X-API-NONCE"] = nonce
  headers["X-API-SIGNATURE"] = signature

  local connection = Connection()
  local content = connection:request("GET", url, nil, nil, headers)
  local json = JSON(content)

  credits = json:dictionary()["credits"]

  return json
end

function nextApiNonce()
  nonce = nonce + 1
  return string.format("%d", nonce)
end

function bin2hex(s)
 return (s:gsub(".", function (byte)
   return string.format("%02x", string.byte(byte))
 end))
end

function signature(nonce, method, uri)
  local md5 = "d41d8cd98f00b204e9800998ecf8427e"
  local hmacData = method .. '#' .. uri .. '#' .. apiKey .. '#' .. nonce .. '#' .. md5
  print("hmac = " .. hmacData)
  return bin2hex(MM.hmac256(apiSecret, hmacData))
end

-- SIGNATURE: MC0CFGbyaCMWCorA2PXbY41sNmlO8OXUAhUAg7QQZRkSCY6zMCOAepSLP4D/pDM=
