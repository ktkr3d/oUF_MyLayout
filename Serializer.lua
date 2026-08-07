local addonName, ns = ...

-- ------------------------------------------------------------------------
-- Profile Export / Import (AceSerializer-3.0 + LibDeflate)
-- ------------------------------------------------------------------------
-- エンコード: AceSerializer でテーブルを文字列化 -> LibDeflate で圧縮 ->
--             LibDeflate の Base64 エンコードで印字可能文字列に変換
-- デコード: Base64 デコード -> LibDeflate 展開 -> AceSerializer デシリアライズ
-- ------------------------------------------------------------------------

local HEADER = "!oUF1!"   -- 識別ヘッダー

-- ライブラリ参照
local AceSerializer = LibStub and LibStub("AceSerializer-3.0", true)
local LibDeflate   = LibStub and LibStub("LibDeflate", true)

-- ------------------------------------------------------------------------
-- ヘルパー: テーブルのディープコピー
-- ------------------------------------------------------------------------
local function DeepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in pairs(orig) do
            copy[DeepCopy(k)] = DeepCopy(v)
        end
        setmetatable(copy, DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- ------------------------------------------------------------------------
-- ns.ExportProfile
-- 現在のプロファイル設定を文字列にエクスポートします。
-- @return string|nil  成功時はエクスポート文字列、失敗時は nil
-- ------------------------------------------------------------------------
function ns.ExportProfile()
    if not AceSerializer then
        print("|cff00ff00oUF_MyLayout:|r |cffff0000Error:|r AceSerializer-3.0 not found.")
        return nil
    end
    if not LibDeflate then
        print("|cff00ff00oUF_MyLayout:|r |cffff0000Error:|r LibDeflate not found.")
        return nil
    end

    -- Serialize the current profile
    local serialized = AceSerializer:Serialize(DeepCopy(ns.Config))
    if not serialized then
        print("|cff00ff00oUF_MyLayout:|r |cffff0000Error:|r Serialization failed.")
        return nil
    end

    -- Compress
    local compressed = LibDeflate:CompressDeflate(serialized, { level = 9 })
    if not compressed then
        print("|cff00ff00oUF_MyLayout:|r |cffff0000Error:|r Compression failed.")
        return nil
    end

    -- Base64 encode for a printable, shareable string
    local encoded = LibDeflate:EncodeForPrint(compressed)
    if not encoded then
        print("|cff00ff00oUF_MyLayout:|r |cffff0000Error:|r Encoding failed.")
        return nil
    end

    return HEADER .. encoded
end

-- ------------------------------------------------------------------------
-- ns.ImportProfile
-- エクスポート文字列を受け取り、現在のプロファイルに適用します。
-- @param str string  エクスポートで生成された文字列
-- @return boolean    成功したかどうか
-- ------------------------------------------------------------------------
function ns.ImportProfile(str)
    if not str or str == "" then
        print("|cff00ff00oUF_MyLayout:|r |cffff0000Error:|r Import string is empty.")
        return false
    end

    if not AceSerializer then
        print("|cff00ff00oUF_MyLayout:|r |cffff0000Error:|r AceSerializer-3.0 not found.")
        return false
    end
    if not LibDeflate then
        print("|cff00ff00oUF_MyLayout:|r |cffff0000Error:|r LibDeflate not found.")
        return false
    end

    -- Validate header
    if str:sub(1, #HEADER) ~= HEADER then
        print("|cff00ff00oUF_MyLayout:|r |cffff0000Error:|r Invalid import string (header mismatch).")
        return false
    end

    local encoded = str:sub(#HEADER + 1)

    -- Base64 decode
    local compressed = LibDeflate:DecodeForPrint(encoded)
    if not compressed then
        print("|cff00ff00oUF_MyLayout:|r |cffff0000Error:|r Decode failed. The string may be corrupted.")
        return false
    end

    -- Decompress
    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then
        print("|cff00ff00oUF_MyLayout:|r |cffff0000Error:|r Decompression failed. The string may be corrupted.")
        return false
    end

    -- Deserialize
    local ok, data = AceSerializer:Deserialize(serialized)
    if not ok or type(data) ~= "table" then
        print("|cff00ff00oUF_MyLayout:|r |cffff0000Error:|r Deserialization failed.")
        return false
    end

    -- Validate minimum required structure
    if type(data.General) ~= "table" or type(data.Units) ~= "table" or type(data.Colors) ~= "table" then
        print("|cff00ff00oUF_MyLayout:|r |cffff0000Error:|r Import data structure is invalid.")
        return false
    end

    -- Write to profile (overwrite existing keys without replacing the ns.Config table itself)
    for k, v in pairs(data) do
        ns.Config[k] = v
    end

    -- Redraw frames
    ns.UpdateFrames()
    if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end

    print("|cff00ff00oUF_MyLayout:|r Profile imported successfully.")
    return true
end
