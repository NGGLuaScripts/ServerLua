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
local requiredSpeed = 40
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

function resetCurrentRunScore()
    -- Son drift skorunu kaydet
    if currentRunScore > 0 then
        lastDriftScore = currentRunScore
    end

    if currentRunScore > personalBestScore then
        personalBestScore = math.floor(currentRunScore)
        personalBestScores[playerID] = personalBestScore
        ac.sendChatMessage("Yeni Kişisel Skor: " .. string.format("%0.0f", personalBestScore):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "") .. " puan!") -- Yeni kişisel skor mesajı
    end

    totalScore = math.floor(totalScore + currentRunScore) -- Toplam skor güncellemesi
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
            driftResetMessage = "Hızın Çok Düşük. 40 KM/h Üzerine Çıkmalısın."
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
        tandemBonus = math.min(1 + (7.5 - nearestCarDistance) / 1.5, 3) -- Tandem Bonusunu x5 ile sınırla
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

    ui.beginTransparentWindow("driftScore", vec2(1700, 100), vec2(1900, 400))

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
    ui.beginTransparentWindow("longDriftBonusBar", vec2(1700, 297), vec2(1900, 540))

    -- Bar arka planı
    ui.drawRectFilled(vec2(0, 0), vec2(200, 20), rgbm(0.2, 0.2, 0.2,  0.7), 10) -- Köşeleri yuvarlak

    -- Bar dolum oranı (anlık güncellenme için pürüzsüz geçiş)
    local smoothFillWidth = math.lerp(0, 200, (LongDriftBonus - 1) / 2) -- x1'i 0 algılar şekilde ayarla
    ui.drawRectFilled(vec2(0, 0), vec2(smoothFillWidth, 20), rgbm(0, 0.2, 0.5, 0.7), 10) -- Köşeleri yuvarlak

    ui.endTransparentWindow()
end

-- Uzun Drift Bonus Barını Çizme
function script.drawTandemDriftBonusBar()
    ui.beginTransparentWindow("longDriftBonusBar", vec2(1700, 276), vec2(1900, 540))

    -- Bar arka planı
    ui.drawRectFilled(vec2(0, 0), vec2(200, 20), rgbm(0.2, 0.2, 0.2,  0.7), 10) -- Köşeleri yuvarlak

    -- Bar dolum oranı (anlık güncellenme için pürüzsüz geçiş)
    local smoothFillWidth = math.lerp(0, 200, (tandemBonus - 1) / 2) -- x1'i 0 algılar şekilde ayarla
    ui.drawRectFilled(vec2(0, 0), vec2(smoothFillWidth, 20), rgbm(0, 0.5, 0.5, 0.7), 10) -- Köşeleri yuvarlak

    ui.endTransparentWindow()
end

-- Uzun Drift Bonus Barını Çizme
function script.drawKomboBar()
    ui.beginTransparentWindow("longDriftBonusBar", vec2(1700, 248), vec2(1900, 540))

    -- Bar arka planı
    ui.drawRectFilled(vec2(0, 0), vec2(200, 22), rgbm(0.2, 0.2, 0.2, 0.7), 10) -- Köşeleri yuvarlak

    -- Bar dolum oranı (anlık güncellenme için pürüzsüz geçiş)
    local smoothFillWidth = math.lerp(0, 200, (smoothComboMeter - 1) / (maxComboMeter - 1)) -- ComboMeter'in pürüzsüz dolumu
    ui.drawRectFilled(vec2(0, 0), vec2(smoothFillWidth, 22), rgbm(0, 0.5, 1, 0.7), 10) -- Köşeleri yuvarlak

    ui.endTransparentWindow()
end

-- Liderlik Tablosunu gösteren fonksiyon
function script.drawLeaderboardUI()

    -- Liderlik Tablosu başlığı
    ui.pushFont(ui.Font.Title)
    ui.textColored("Liderlik Tablosu:", rgbm(1, 0.3, 0.2, 1))
    ui.popFont()

    -- Skorları sıralama
    local sortedScores = {}
    for player, score in pairs(personalBestScores) do
        table.insert(sortedScores, {player = player, score = score})
    end
    table.sort(sortedScores, function(a, b) return a.score > b.score end)

    -- Liderlik Tablosu öğeleri
    for i, data in ipairs(sortedScores) do
        ui.pushFont(ui.Font.Main)
        ui.textColored(string.format("%d. %s: %s", i, data.player, string.format("%0.0f", data.score):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")), rgbm(0.7, 0.7, 0.7, 1))
        ui.popFont()
    end
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

