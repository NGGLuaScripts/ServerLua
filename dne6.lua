-- Drift Puanlama ve Fonksiyonlar

local driftScores = {}
local personalBestScores = {}
local playerID = ac.getDriverName()
local maxPlayers = 24
local nearestCarDistance = 9999999
local tandemBonus = 1
local minDriftAngle = 20
local previousDamage = 0
local speedThreshold = 10
local requiredSpeed = 25
local comboMeter = 1
local comboProgress = 0
local highestCombo = 1
local dangerouslySlowTimer = 0
local currentRunScore = 0
local personalBestScore = 0
local totalScore = 0 -- Toplam skor eklendi
local lastDriftScore = 0 -- Son drift skoru
local maxComboMeter = 50
local comboDecayRate = 0.02
local driftResetMessage = ""
local messageTimer = 0
local LongDriftTimer = 0
local LongDriftBonus = 1
local ExtraScoreMultiplier = 1
local smoothComboMeter = 1 -- Pürüzsüz kombo ilerlemesi için

-- Her oyuncu için ayrı değerler tutacak tablolar
local playerCombos = {}
local playerTandemBonuses = {}
local playerLongDriftBonuses = {}
local playerDriftScores = {}

function initializePlayerData(driverName)
    if not playerCombos[driverName] then
        playerCombos[driverName] = {
            comboMeter = 1,
            comboProgress = 0,
            smoothComboMeter = 1
        }
    end
    if not playerTandemBonuses[driverName] then
        playerTandemBonuses[driverName] = 1
    end
    if not playerLongDriftBonuses[driverName] then
        playerLongDriftBonuses[driverName] = 1
    end
    if not playerDriftScores[driverName] then
        playerDriftScores[driverName] = 0
    end
end

function calculatePlayerCombo(driverName, angle, speed, dt)
    if not playerCombos[driverName] then return 1 end
    
    local combo = playerCombos[driverName]
    local angleContribution = math.abs(angle) * 0.2
    local speedContribution = speed * 0.2
    local combinedContribution = angleContribution + speedContribution

    if math.abs(angle) > 25 and speed > requiredSpeed then
        combo.comboProgress = combo.comboProgress + combinedContribution * 0.05 * dt
        if combo.comboProgress >= 1 then
            combo.comboMeter = math.min(maxComboMeter, combo.comboMeter + math.floor(combo.comboProgress))
            combo.comboProgress = combo.comboProgress - math.floor(combo.comboProgress)
        end
    else
        combo.comboProgress = math.max(0, combo.comboProgress - comboDecayRate * dt)
        combo.comboMeter = math.max(1, combo.comboMeter - comboDecayRate * 10 * dt)
    end
    
    combo.smoothComboMeter = math.lerp(combo.smoothComboMeter, combo.comboMeter, dt * 5)
    return combo.comboMeter
end

function updateDriftScores(playerID, score)
    if driftScores[playerID] then
        driftScores[playerID] = driftScores[playerID] + score
    else
        driftScores[playerID] = score
    end

    if not personalBestScores[playerID] or personalBestScores[playerID] < score then
        personalBestScores[playerID] = math.floor(score)
    end
end

-- Skor senkronizasyonu için yeni fonksiyonlar
function broadcastScore(driverName, score)
    -- Skor formatını düzelt ve mesajı gönder
    local message = string.format("DRIFT_SCORE|%s|%d", tostring(driverName), math.floor(score))
    ac.sendChatMessage(message)
end

function script.onChatMessage(message, senderCarIndex, senderSessionID)
    -- DRIFT_SCORE|oyuncuAdı|skor formatında mesaj kontrolü
    if message:find("DRIFT_SCORE|") then
        local _, _, driverName, scoreStr = message:find("DRIFT_SCORE|([^|]+)|(%d+)")
        if driverName and scoreStr then
            local score = tonumber(scoreStr)
            if score then
                -- Skoru güncelle ve debug mesajı gönder
                personalBestScores[driverName] = score
                ac.debug("Skor güncellendi - Oyuncu: " .. driverName .. ", Skor: " .. score)
            end
        end
    end
end

function resetCurrentRunScore()
    -- Son drift skorunu kaydet
    if currentRunScore > 0 then
        lastDriftScore = currentRunScore
    end

    -- Eğer yeni rekor kırıldıysa
    if currentRunScore > personalBestScore then
        personalBestScore = math.floor(currentRunScore)
        personalBestScores[playerID] = personalBestScore
        
        -- Yeni skoru diğer oyunculara bildir
        broadcastScore(playerID, personalBestScore)
        
        -- Başarı mesajını gönder
        local formattedScore = string.format("%0.0f", personalBestScore):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
        ac.sendChatMessage("Yeni Kişisel Skor: " .. formattedScore .. " puan!")
    end

    -- Mevcut oyuncunun drift skorlarını sıfırla
    playerDriftScores[playerID] = 0
    totalScore = math.floor(totalScore + currentRunScore)
    currentRunScore = 0
    comboMeter = 1
    comboProgress = 0
    driftResetMessage = "Drift Turu Sıfırlandı!"
    messageTimer = 3
end

function getNearestCarDistance()
    local playerCarPos = ac.getCar(0).position
    local lowestDist = 9999999
    for i = 1, maxPlayers do
        if ac.getCar(i) and i ~= 0 then
            local car = ac.getCar(i)
            if car.isConnected and not car.isInPit and not car.isInPitlane then
                local distance = math.distance(playerCarPos, car.position)
                if distance < lowestDist then
                    lowestDist = distance
                end
            end
        end
    end
    return lowestDist
end

function calculateDriftScore(angle, speed, multiplier, dt, tandemBonus)
    if math.abs(angle) >= minDriftAngle and speed > requiredSpeed then
        return (math.abs(angle) - minDriftAngle) * speed * multiplier * tandemBonus * dt * 0.05 * ExtraScoreMultiplier
    end
    return 0
end

function getDriftAngleFromGForce(car)
    local gForceX = car.localVelocity.x / 9.81
    local gForceZ = car.localVelocity.z / 9.81
    return math.abs(math.deg(math.atan2(gForceX, gForceZ)))
end

function calculateComboMeter(angle, speed, dt)
    local angleContribution = math.abs(angle) * 0.2
    local speedContribution = speed * 0.2
    local combinedContribution = angleContribution + speedContribution

    if math.abs(angle) > 25 and speed > requiredSpeed then
        comboProgress = comboProgress + combinedContribution * 0.05 * dt
        if comboProgress >= 1 then
            comboMeter = math.min(maxComboMeter, comboMeter + math.floor(comboProgress))
            comboProgress = comboProgress - math.floor(comboProgress)
        end
    else
        comboProgress = math.max(0, comboProgress - comboDecayRate * dt)
        comboMeter = math.max(1, comboMeter - comboDecayRate * 10 * dt)
    end
end

local UIToggle = true
local LastKeyState = false
function script.update(dt)
    -- Tüm oyuncuların drift skorlarını güncelle
    for i = 0, maxPlayers - 1 do
        local car = ac.getCar(i)
        local driverName = ac.getDriverName(i)
        if car and car.isConnected and driverName and driverName ~= "" then
            initializePlayerData(driverName)
            
            -- Sadece kendi skorumuzu hesapla
            if driverName == playerID then
                local driftAngle = getDriftAngleFromGForce(car)
                local speed = math.sqrt(car.velocity.x^2 + car.velocity.z^2) * 3.6
                
                local playerCombo = calculatePlayerCombo(driverName, driftAngle, speed, dt)
                
                local nearestDist = getNearestCarDistance()
                if nearestDist < 7.5 then
                    playerTandemBonuses[driverName] = math.min(1 + (7.5 - nearestDist) / 1.5, 3)
                else
                    playerTandemBonuses[driverName] = 1
                end
                
                local driftScore = calculateDriftScore(driftAngle, speed, playerCombo, dt, playerTandemBonuses[driverName])
                
                if driftScore > 0 then
                    if not playerDriftScores[driverName] then
                        playerDriftScores[driverName] = 0
                    end
                    playerDriftScores[driverName] = playerDriftScores[driverName] + driftScore
                    currentRunScore = playerDriftScores[driverName]
                    
                    -- Eğer mevcut skor kişisel en iyiyi geçtiyse güncelle ve yayınla
                    if currentRunScore > (personalBestScores[driverName] or 0) then
                        personalBestScores[driverName] = math.floor(currentRunScore)
                        -- Her yeni rekor kırıldığında skoru yayınla
                        broadcastScore(driverName, personalBestScores[driverName])
                    end
                end
                
                -- Sıfırlama kontrolleri
                if car.wheelsOutside > 3 or (tonumber(car.damage) or 0) > previousDamage then
                    resetCurrentRunScore()
                end
            end
        end
    end

    -- Klavye kombinasyonu kontrolü
    local keyState = ac.isKeyDown(ac.KeyIndex.Shift) and ac.isKeyDown(ac.KeyIndex.H)
    if keyState and LastKeyState ~= keyState then
        UIToggle = not UIToggle
        LastKeyState = keyState
    elseif not keyState then
        LastKeyState = false
    end

    local car = ac.getCar(0)
    local driftAngle = getDriftAngleFromGForce(car)
    local speed = math.sqrt(car.velocity.x^2 + car.velocity.z^2) * 3.6

    if car.wheelsOutside > 3 then
        resetCurrentRunScore()
        driftResetMessage = "Yolun Dışına Çıktın!"
        messageTimer = 3
        return
    end

    -- Pürüzsüz combo ilerlemesi
    smoothComboMeter = math.lerp(smoothComboMeter, comboMeter, dt * 5)

    local currentDamage = tonumber(car.damage) or 0
    if currentDamage > previousDamage then
        resetCurrentRunScore()
        driftResetMessage = "Çarpma algılandı!"
        messageTimer = 3
        previousDamage = currentDamage
        return
    end
    previousDamage = currentDamage

    if speed < requiredSpeed then
        dangerouslySlowTimer = dangerouslySlowTimer + dt
        if dangerouslySlowTimer > 2 then
            resetCurrentRunScore()
            driftResetMessage = "Hızın Çok Düşük. 25 KM/h Üzerine Çıkmalısın."
            messageTimer = 1
            return
        end
    else
        dangerouslySlowTimer = 0
    end

    if math.abs(driftAngle) >= minDriftAngle and speed > requiredSpeed then
        LongDriftTimer = LongDriftTimer + dt
    else
        LongDriftTimer = 0
    end

    if LongDriftTimer > 3 then
        LongDriftBonus = math.min(0.5 * math.floor(LongDriftTimer / 1.25), 3) -- Uzun Drift Bonusunu x0'dan başlayarak 0.25 artacak şekilde ayarla
        ExtraScoreMultiplier = LongDriftBonus
    else
        LongDriftBonus = 1
        ExtraScoreMultiplier = 1
    end

    nearestCarDistance = getNearestCarDistance()
    if nearestCarDistance < 7.5 then
        tandemBonus = math.min(1 + (7.5 - nearestDist) / 1.5, 3) -- Tandem Bonusunu x5 ile sınırla
    else
        tandemBonus = 1
    end

    calculateComboMeter(driftAngle, speed, dt)

    local driftScore = calculateDriftScore(driftAngle, speed, comboMeter, dt, tandemBonus)
    currentRunScore = currentRunScore + driftScore
    if comboMeter > highestCombo then
        highestCombo = comboMeter
    end

    if driftScore > 0 then
        if currentRunScore > personalBestScore then
            personalBestScore = math.floor(currentRunScore)
            personalBestScores[playerID] = personalBestScore
        end
        updateDriftScores(playerID, driftScore)
    end

    if messageTimer > 0 then
        messageTimer = messageTimer - dt
        if messageTimer <= 0 then
            driftResetMessage = ""
        end
    end
end

-- Drift Skoru ve diğer bilgileri gösteren fonksiyon
function script.drawDriftScoreUI()
    local uiState = ac.getUiState()

    ui.beginTransparentWindow("driftScore", vec2(1300, 100), vec2(1900, 400))

    -- Drift Skoru başlığı
    ui.pushFont(ui.Font.Huge)
    ui.beginOutline()
    local scoreText = string.format("DRIFT PUANI: ")
    local scoreValue = string.format("%s", string.format("%0.0f", currentRunScore):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", ""))
    ui.textColored(scoreText, rgbm(1, 1, 1, 1)) -- Başlık için beyaz renk
    ui.sameLine(0, 5) -- Aynı satırda yazmaya devam et
    ui.textColored(scoreValue, rgbm(0, 1, 0, 1)) -- Puan kısmını yeşil yap
    ui.sameLine(0, 5)
    ui.pushFont(ui.Font.Italic)
    ui.textColored("Pts", rgbm(0.7, 0.7, 0.7, 1)) -- "PUAN" kelimesi italik ve turuncu
    ui.popFont()
    ui.popFont()
    ui.endOutline(rgbm(0, 0, 0, 1))


    -- Son Drift Skoru
    ui.beginOutline()
    ui.pushFont(ui.Font.Main)
	ui.textColored("Son Drift Puanı: " .. string.format("%0.0f", lastDriftScore):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "") .. " Pts", rgbm(0.7, 0.7, 0.8, 1))
    ui.popFont()
    ui.endOutline(rgbm(0, 0, 0, 0.08))

    -- Toplam Skor ve Kişisel Skor
    ui.beginOutline()
    ui.pushFont(ui.Font.Main)
	ui.textColored("Toplam Drift Puanı: " .. string.format("%0.0f", totalScore):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "") .. " Pts", rgbm(0.7, 0.7, 0.8, 1))
	ui.textColored("Kişisel En İyi Puan: " .. string.format("%0.0f", personalBestScore):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "") .. " Pts", rgbm(0.7, 0.7, 0.8, 1))
    ui.popFont()
    ui.endOutline(rgbm(0, 0, 0, 0.08))

    -- Combo
    ui.beginOutline()        
    ui.pushFont(ui.Font.Title)
    ui.textColored("Kombo: x" .. string.format("%.2f", smoothComboMeter), rgbm(1, 0.9, 0.2, 1)) -- Pürüzsüz combo ilerlemesi gösterilir
    ui.popFont()
    ui.endOutline(rgbm(0, 0, 0, 0.15))

    -- Bonuslar
    ui.beginOutline()
    ui.pushFont(ui.Font.Italic)
    ui.textColored("Tandem Drift Bonusu: " .. string.format("x%.2f", tandemBonus), rgbm(1, 0.7, 0.2, 1))
    ui.textColored("Uzun Drift Bonusu: " .. string.format("x%.2f", LongDriftBonus), rgbm(1, 0.7, 0.2, 1))
    ui.popFont()
    ui.endOutline(rgbm(0, 0, 0, 0.15))

    ui.pushFont(ui.Font.Italic)
    ui.beginOutline()
    -- Drift Açısı
    ui.textColored("Drift Açısı: " .. string.format("%.1f°", getDriftAngleFromGForce(ac.getCar(0))), rgbm(0, 0.8, 1, 1))
    ui.endOutline(rgbm(0, 0, 0, 0.25))
    ui.popFont()
	
    ui.pushFont(ui.Font.Italic)
    ui.beginOutline()
	
    -- Drift Açısı
    ui.textColored("SHIFT+H İle HUD'u Gizleyebilirsin.", rgbm(0, 0.5, 0.1, 1))
    ui.endOutline(rgbm(0, 0, 0, 0.25))
    ui.popFont()

    -- Drift Reset mesajı
    if driftResetMessage ~= "" then
        ui.pushFont(ui.Font.Title)
        ui.beginOutline()
        ui.textColored(driftResetMessage, rgbm(1, 0, 0, 1))
        ui.popFont()
        ui.endOutline(rgbm(0, 0, 0, 0.15))
    end

    ui.endTransparentWindow()
end

-- Uzun Drift Bonus Barını Çizme
function script.drawLongDriftBonusBar()
    ui.beginTransparentWindow("longDriftBonusBar", vec2(1300, 297), vec2(1900, 540))

    -- Bar arka planı
    ui.drawRectFilled(vec2(0, 0), vec2(200, 20), rgbm(0.2, 0.2, 0.2,  0.7), 10) -- Köşeleri yuvarlak

    -- Bar dolum oranı (anlık güncellenme için pürüzsüz geçiş)
    local smoothFillWidth = math.lerp(0, 200, (LongDriftBonus - 1) / 2) -- x1'i 0 algılar şekilde ayarla
    ui.drawRectFilled(vec2(0, 0), vec2(smoothFillWidth, 20), rgbm(0, 0.2, 0.5, 0.7), 10) -- Köşeleri yuvarlak

    ui.endTransparentWindow()
end

-- Uzun Drift Bonus Barını Çizme
function script.drawTandemDriftBonusBar()
    ui.beginTransparentWindow("longDriftBonusBar", vec2(1300, 276), vec2(1900, 540))

    -- Bar arka planı
    ui.drawRectFilled(vec2(0, 0), vec2(200, 20), rgbm(0.2, 0.2, 0.2,  0.7), 10) -- Köşeleri yuvarlak

    -- Bar dolum oranı (anlık güncellenme için pürüzsüz geçiş)
    local smoothFillWidth = math.lerp(0, 200, (tandemBonus - 1) / 2) -- x1'i 0 algılar şekilde ayarla
    ui.drawRectFilled(vec2(0, 0), vec2(smoothFillWidth, 20), rgbm(0, 0.5, 0.5, 0.7), 10) -- Köşeleri yuvarlak

    ui.endTransparentWindow()
end

-- Uzun Drift Bonus Barını Çizme
function script.drawKomboBar()
    ui.beginTransparentWindow("longDriftBonusBar", vec2(1300, 248), vec2(1900, 540))

    -- Bar arka planı
    ui.drawRectFilled(vec2(0, 0), vec2(200, 22), rgbm(0.2, 0.2, 0.2, 0.7), 10) -- Köşeleri yuvarlak

    -- Bar dolum oranı (anlık güncellenme için pürüzsüz geçiş)
    local smoothFillWidth = math.lerp(0, 200, (smoothComboMeter - 1) / (maxComboMeter - 1)) -- ComboMeter'in pürüzsüz dolumu
    ui.drawRectFilled(vec2(0, 0), vec2(smoothFillWidth, 22), rgbm(0, 0.5, 1, 0.7), 10) -- Köşeleri yuvarlak

    ui.endTransparentWindow()
end

-- Liderlik tablosunu güncelleyen fonksiyon
function updateLeaderboard()
    local sortedScores = {}
    -- Tüm aktif oyuncuları kontrol et
    for i = 0, maxPlayers - 1 do
        local car = ac.getCar(i)
        local driverName = ac.getDriverName(i)
        if car and car.isConnected and driverName and driverName ~= "" and driverName ~= "function: 0xff" then
            -- Sadece kaydedilmiş en iyi skorları kullan
            if not personalBestScores[driverName] then
                personalBestScores[driverName] = 0
            end
            
            table.insert(sortedScores, {
                player = driverName,
                score = personalBestScores[driverName],
                isOnline = true,
                carIndex = i
            })
            
            -- Debug mesajı
            ac.debug("Oyuncu: " .. driverName .. ", Skor: " .. personalBestScores[driverName])
        end
    end
    
    -- Skorları büyükten küçüğe sırala
    table.sort(sortedScores, function(a, b) return a.score > b.score end)
    
    -- Sadece ilk 10 oyuncuyu döndür
    local top10 = {}
    for i = 1, math.min(10, #sortedScores) do
        table.insert(top10, sortedScores[i])
    end
    
    return top10
end

function script.drawLeaderboardUI()
    local sortedScores = updateLeaderboard()
    
    ui.beginTransparentWindow("leaderboard", vec2(1300, 400), vec2(1900, 800))
    
    -- Başlık
    ui.pushFont(ui.Font.Title)
    ui.beginOutline()
    ui.textColored("TOP 10 EN İYİ DRIFT SKORLARI", rgbm(1, 0.8, 0.2, 1))
    ui.endOutline(rgbm(0, 0, 0, 0.5))
    ui.popFont()
    
    -- Sıralama listesi
    for i, data in ipairs(sortedScores) do
        if data.player and data.player ~= "function: 0xff" then
            ui.pushFont(ui.Font.Main)
            -- Mevcut oyuncuyu farklı renkte göster
            local isCurrentPlayer = (data.carIndex == 0)
            local textColor = isCurrentPlayer and rgbm(0, 1, 0, 1) or rgbm(1, 1, 1, 0.8)
            
            -- Sıralama numarası ve oyuncu adı
            local rankText = string.format("%d. %s", i, data.player)
            ui.beginOutline()
            ui.textColored(rankText, textColor)
            
            -- Skor
            ui.sameLine(0, 20)
            local scoreText = string.format("%s Pts", string.format("%0.0f", data.score):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", ""))
            ui.textColored(scoreText, textColor)
            ui.endOutline(rgbm(0, 0, 0, 0.3))
            ui.popFont()
        end
    end
    
    ui.endTransparentWindow()
end

-- Ana fonksiyon veya oyun döngüsü içinde her iki fonksiyonu çağırabilirsiniz:
function script.drawUI()
	if UIToggle then
    -- Drift Skoru UI'sini göster
    script.drawDriftScoreUI()
    -- Liderlik Tablosu UI'sini göster
    script.drawLeaderboardUI()
	--
	script.drawLongDriftBonusBar()
	--
	script.drawTandemDriftBonusBar()
	--
	script.drawKomboBar()
end
end

