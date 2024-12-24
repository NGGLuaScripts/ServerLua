-- Çevrimiçi sunucular için geliştirilmiş drift kodu
local sqlite = require("lsqlite3")
local db = sqlite.open("drift.db")

-- Veritabanı tablolarını oluşturma
local function initializeDatabase()
    db:exec([[CREATE TABLE IF NOT EXISTS scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playerID TEXT,
        totalScore INTEGER,
        personalBest INTEGER
    )]])
end

initializeDatabase()

local driftScores = {}
local personalBestScores = {}
local playerID = ac.getDriverName() -- Oyuncu adı/ID'si alınır
local maxPlayers = 24 -- Sunucudaki maksimum oyuncu sayısı
local nearestCarDistance = 9999999 -- En yakın araca olan mesafe
local tandemBonus = 1 -- Tandem bonus çarpanı
local minDriftAngle = 20 -- Minimum drift açısı
local previousDamage = 0 -- Önceki hasar durumu
local speedThreshold = 10 -- Hızdaki ani değişim için eşik değer
local requiredSpeed = 40 -- Minimum drift hızı
local comboMeter = 1
local comboProgress = 0
local highestCombo = 1
local dangerouslySlowTimer = 0
local currentRunScore = 0 -- Şu anki drift tur skoru
local personalBestScore = 0 -- Kişisel en iyi drift skoru
local maxComboMeter = 50 -- Maksimum combo çarpanı
local comboDecayRate = 0.02 -- Combo azalma hızı
local driftResetMessage = "" -- Drift sıfırlama mesajı
local messageTimer = 0 -- Mesaj zamanlayıcısı
local LongDriftTimer = 0 -- Uzun drift süresi
local LongDriftBonus = 1 -- Uzun drift bonus çarpanı
local ExtraScoreMultiplier = 1 -- Ekstra skor çarpanı

-- Veritabanından skorları yükleme
local function loadScores()
    for row in db:nrows("SELECT * FROM scores") do
        driftScores[row.playerID] = row.totalScore
        personalBestScores[row.playerID] = row.personalBest
    end
end

loadScores()

-- Skorları veritabanına kaydetme
local function saveScoreToDatabase(playerID, totalScore, personalBest)
    local stmt = db:prepare("INSERT INTO scores (playerID, totalScore, personalBest) VALUES (?, ?, ?) ON CONFLICT(playerID) DO UPDATE SET totalScore = ?, personalBest = ?")
    stmt:bind_values(playerID, totalScore, personalBest, totalScore, personalBest)
    stmt:step()
    stmt:finalize()
end

-- Skor tablosu güncelleme
function updateDriftScores(playerID, score)
    if driftScores[playerID] then
        driftScores[playerID] = driftScores[playerID] + score
    else
        driftScores[playerID] = score
    end

    if not personalBestScores[playerID] or personalBestScores[playerID] < score then
        personalBestScores[playerID] = math.floor(score)
    end

    saveScoreToDatabase(playerID, driftScores[playerID], personalBestScores[playerID])
end

-- Drift tur skorunu sıfırlama
function resetCurrentRunScore()
    if currentRunScore > personalBestScore then
        personalBestScore = math.floor(currentRunScore)
        personalBestScores[playerID] = personalBestScore
        saveScoreToDatabase(playerID, driftScores[playerID] or 0, personalBestScore)
    end
    currentRunScore = 0
    comboMeter = 1
    comboProgress = 0
    driftResetMessage = "Drift Turu Sıfırlandı!"
    messageTimer = 3 -- Mesaj 3 saniye boyunca gösterilecek
end

-- Drift puanını hesaplama
function calculateDriftScore(angle, speed, multiplier, dt, tandemBonus)
    if math.abs(angle) >= minDriftAngle and speed > requiredSpeed then
        return (math.abs(angle) - minDriftAngle) * speed * multiplier * tandemBonus * dt * 0.1 * ExtraScoreMultiplier
    end
    return 0
end

-- Drift işlemlerini kontrol etme
function script.update(dt)
    local car = ac.getCar(0) -- Oyuncunun aracı
    local driftAngle = getDriftAngleFromGForce(car)
    local speed = math.sqrt(car.velocity.x^2 + car.velocity.z^2) * 3.6 -- m/s -> km/h

    -- Zeminden çıkma kontrolü
    if car.wheelsOutside > 0 then
        resetCurrentRunScore()
        driftResetMessage = "Asfalt dışına çıktınız!"
        messageTimer = 3 -- Mesaj 3 saniye boyunca gösterilecek
        return
    end

    -- Çarpma kontrolü: Hasar durumu
    local currentDamage = tonumber(car.damage) or 0 -- `car.damage` bir sayı değilse sıfır varsay
    if currentDamage > previousDamage then
        resetCurrentRunScore()
        driftResetMessage = "Çarpma algılandı!"
        messageTimer = 3 -- Mesaj 3 saniye boyunca gösterilecek
        previousDamage = currentDamage
        return
    end
    previousDamage = currentDamage

    -- Hız kontrolü
    if speed < requiredSpeed then
        dangerouslySlowTimer = dangerouslySlowTimer + dt
        if dangerouslySlowTimer > 2 then
            resetCurrentRunScore()
            driftResetMessage = "Hız çok düşük!"
            messageTimer = 3 -- Mesaj 3 saniye boyunca gösterilecek
            return
        end
    else
        dangerouslySlowTimer = 0
    end

    -- Uzun drift bonusunu hesapla
    if math.abs(driftAngle) >= minDriftAngle and speed > requiredSpeed then
        LongDriftTimer = LongDriftTimer + dt
    else
        LongDriftTimer = 0
    end

    if LongDriftTimer > 3 then
        LongDriftBonus = math.ceil((LongDriftTimer / 9) * 10 + 6.666) / 10
        ExtraScoreMultiplier = LongDriftBonus
    else
        LongDriftBonus = 1
        ExtraScoreMultiplier = 1
    end

    -- Drift puanı hesapla
    local driftScore = calculateDriftScore(driftAngle, speed, comboMeter, dt, tandemBonus)
    currentRunScore = currentRunScore + driftScore
    if comboMeter > highestCombo then
        highestCombo = comboMeter
    end

    -- Oyuncu skorunu güncelle
    if driftScore > 0 then
        if currentRunScore > personalBestScore then
            personalBestScore = math.floor(currentRunScore)
            personalBestScores[playerID] = personalBestScore
        end
        updateDriftScores(playerID, driftScore)
    end

    -- Mesaj zamanlayıcısını güncelle
    if messageTimer > 0 then
        messageTimer = messageTimer - dt
        if messageTimer <= 0 then
            driftResetMessage = ""
        end
    end
end

-- UI Çizimleri
function script.drawUI()
    local screensize = vec2(ac.getSim().windowWidth, ac.getSim().windowHeight)
    local centerX = screensize.x / 2
    local offsetY = screensize.y / 3 -- Ortanın üst kısmı

    -- Skorları ve diğer bilgileri gösteren mesajlar
    local messages = {
        string.format("Toplam Skor: %d", math.floor(driftScores[playerID] or 0)),
        string.format("Drift Tur Skoru: %d", math.floor(currentRunScore)),
        string.format("Drift Açısı: %.1f°", math.abs(getDriftAngleFromGForce(ac.getCar(0)))),
        string.format("Combo: x%.1f", comboMeter),
        string.format("Tandem Bonus: x%.2f", tandemBonus),
        string.format("Uzun Drift Bonus: x%.2f", LongDriftBonus),
        string.format("Kişisel En İyi Skor: %d", personalBestScore)
    }

    for i, msg in ipairs(messages) do
        local posY = offsetY + (i - 1) * 30
        ui.text(msg, vec2(centerX, posY), 20, rgbm(1, 1, 1, 1), ui.Alignment.Center)
    end

    -- Combo İlerleme Çubuğu
    local barWidth = 300
    local barHeight = 20
    local barPosX = centerX - barWidth / 2
    local barPosY = offsetY + (#messages * 30) + 20
    local progress = math.lerp(0, 1, comboMeter / maxComboMeter)

    -- Barın arka planı
    ui.drawRectFilled(vec2(barPosX, barPosY), vec2(barPosX + barWidth, barPosY + barHeight), rgbm(0.2, 0.2, 0.2, 1))
    -- Barın dolu kısmı
    ui.drawRectFilled(vec2(barPosX, barPosY), vec2(barPosX + barWidth * progress, barPosY + barHeight), rgbm(0, 1, 0, 1))

    -- Barın kenar hatları
    ui.drawLine(vec2(barPosX, barPosY), vec2(barPosX + barWidth, barPosY), rgbm(0.8, 0.8, 0.8, 1), 2)
    ui.drawLine(vec2(barPosX, barPosY + barHeight), vec2(barPosX + barWidth, barPosY + barHeight), rgbm(0.8, 0.8, 0.8, 1), 2)

    -- Drift sıfırlama mesajı
    if driftResetMessage ~= "" then
        local messagePosY = offsetY - 50
        ui.text(driftResetMessage, vec2(centerX, messagePosY), 25, rgbm(1, 0, 0, 1), ui.Alignment.Center)
    end

    -- Liderlik Tablosu
    local leaderboardY = offsetY + (#messages * 30) + 60
    ui.text("Liderlik Tablosu", vec2(centerX, leaderboardY), 25, rgbm(1, 1, 0, 1), ui.Alignment.Center)

    local sortedScores = {}
    for player, score in pairs(personalBestScores) do
        table.insert(sortedScores, {player = player, score = score})
    end
    table.sort(sortedScores, function(a, b) return a.score > b.score end)

    for i, data in ipairs(sortedScores) do
        local posY = leaderboardY + i * 25
        ui.text(string.format("%d. %s: %d", i, data.player, math.floor(data.score)), vec2(centerX, posY), 20, rgbm(1, 1, 1, 1), ui.Alignment.Center)
    end
end

-- Sunucuya skorları düzenli olarak gönderme
function script.onSessionEnd()
    db:close()
end
