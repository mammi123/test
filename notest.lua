local DISCORD_TOKEN = getgenv().token
local TARGET_CHANNEL_ID = getgenv().channel_id

if not token or not webhook then
    error("❌ Token veya Webhook URL tanımlı değil. Lütfen script başında tanımla.")
end


local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local requestFunc = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
if type(requestFunc) ~= "function" then
    warn("HATA: HTTP request fonksiyonu geçersiz.")
    return
end


local hasActionBeenRun = false -- Coroutine yerine basit bir bayrak

-- Komut ayrıştırma fonksiyonu
local function parseTeleportCommand(content)
    if not content then return nil, nil end
    local placeId, jobId = content:match('TeleportToPlaceInstance%((%d+),%s*"([^"]+)"%)')
    return placeId, jobId
end

-- Işınlanma fonksiyonu
local function joinServer(placeId, jobId, player)
    print("LOG: Işınlanma başlatılıyor. Hedef Place ID: " .. placeId .. ", Job ID: " .. jobId)
    pcall(function()
        TeleportService:TeleportToPlaceInstance(tonumber(placeId), jobId, player)
    end)
end

-- [YENİ] Sınırlı Eylem Fonksiyonu
local function performFiniteActions()
    hasActionBeenRun = true -- Bu sunucu için eylemlerin başladığını işaretle
    print("LOG: Sınırlı eylem modu başlatılıyor (3 chat, 10 zıplama)...")

    local player = Players.LocalPlayer
    if not player then
        warn("HATA: Eylem başlatılırken LocalPlayer bulunamadı.")
        return
    end

    local character = player.Character or player.CharacterAdded:Wait()
    if not character then return end

    local humanoid = character:WaitForChild("Humanoid")
    if not humanoid then return end

    -- Chat Eylemi (3 kere)
    task.spawn(function()
        for i = 1, 3 do
            if not humanoid or humanoid.Health <= 0 then break end -- Eğer ölürse döngüyü kır
            print("LOG: Mesaj gönderiliyor... (" .. i .. "/3)")
            pcall(function() game:GetService("TextChatService").TextChannels.RBXGeneral:SendAsync("31") end)
            task.wait(5)
        end
        print("LOG: Chat eylemi tamamlandı.")
    end)

    -- Zıplama Eylemi (10 kere)
    task.spawn(function()
        for i = 1, 10 do
            if not humanoid or humanoid.Health <= 0 then break end -- Eğer ölürse döngüyü kır
            print("LOG: Zıplanıyor... (" .. i .. "/10)")
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            task.wait(1)
        end
        print("LOG: Zıplama eylemi tamamlandı.")
    end)
end

-- Ana döngü
local function start()
	if not requestFunc then warn("HATA: Executor'da 'request' fonksiyonu bulunamadı.") return end
	if not TARGET_CHANNEL_ID or TARGET_CHANNEL_ID == "BURAYA_KANAL_IDSINI_YAPISTIR" then warn("HATA: Lütfen script'in içine doğru Kanal ID'sini gir.") return end
	
	print("Otomatik katılım scripti başlatıldı. Discord dinleniyor...")

	while task.wait(8) do
        print("LOG: Yeni bir Discord kontrolü yapılıyor...")
		local requestUrl = "https://discord.com/api/v10/channels/" .. TARGET_CHANNEL_ID .. "/messages?limit=1"
		
        local success, response = pcall(function() return requestFunc({ Url = requestUrl, Method = "GET", Headers = {["Authorization"] = DISCORD_TOKEN} }) end)
        if not success or not response or not response.Success or response.StatusCode ~= 200 then warn("HATA: Discord API'den yanıt alınamadı. Status: " .. (response and response.StatusMessage or "Bilinmiyor")) continue end

        local success_decode, data = pcall(function()
    		return HttpService:JSONDecode(response.Body)
	end)

        if not success_decode or not data or #data == 0 then print("LOG: Kanalda mesaj yok veya veri bozuk.") continue end

        if data[1] and data[1].content then
            local placeId, jobId = parseTeleportCommand(data[1].content)
            
            if placeId and jobId then
                if jobId ~= game.JobId then
                    hasActionBeenRun = false -- Farklı bir sunucu hedefi var, bayrağı sıfırla
                    local player = Players.LocalPlayer
                    if player then joinServer(placeId, jobId, player) end
                else
                    if not hasActionBeenRun then
                        print("LOG: Zaten hedef sunucudasın. Eylemler başlatılıyor.")
                        performFiniteActions()
                    else
                        print("LOG: Zaten hedef sunucudasın ve eylemler zaten yapıldı. Yeni sunucu bekleniyor.")
                    end
                end
            end
        end
	end
end

start()
