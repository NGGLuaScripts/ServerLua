Settings = ac.storage({
	KeyValue = 999, --key value for ac
	KeyName = "", --key name for user
	TPtoCam = false,
	ShowKeyTP = true,
	tpDistance = 8,
	SpectatePlayer = false,
	MousetoTrackRays = false,
	MousetoTrackRays_updates = "500",
	MousetoTrackRays_Chord_keyValue = 999,
	MousetoTrackRays_Chord_KeyName = "",
	MousetoTrackRays_pos_keyValue = 999,
	MousetoTrackRays_pos_KeyName = "",
	MousetoTrackRays_dir_keyValue = 999,
	MousetoTrackRays_dir_KeyName = "",
	MousetoTrackRays_TP_keyValue = 999,
	MousetoTrackRays_TP_KeyName = "",
})

local timer = {
	running = 5,	--we move length/blength into here
	length = 5,		--the normal length after teleporting
	blength = 0.5,	--length after setting a button
}

--#region [Menu]
local function Teleportation()
	--showing timer seems logical to me here
	ui.text("Bekleme Süresi: " .. math.round(timer.running, 1))

	ui.tabBar("Atabbar", function()
		ui.tabItem("Işınlanma Menüsü", CartoCar_UI)
	end)
end
--#endregion

--#region [Car to Car] --physics stuff works in ui shit too so lol
function CartoCar_UI()
	ui.text("Işınlanacağın Arkadaşını Seç ve 'IŞINLAN' tuşuna bas.")
if ui.button("Işınlan") and selectedCar and timer.running <= 0 then -- check if car selected/button pressed/timer above 0
					timer.running = timer.length
					local dir = selectedCar.look

                    local playerVelocity = ac.getCarState(1).velocity
                    local playerGear = ac.getCarState(1).gear
                    local playerRPM = ac.getCarState(1).rpm
                    print(playerGear)
                    print(playerRPM)

					physics.setCarPosition(0, selectedCar.position + vec3(0, 0.1, 0) - dir * 10, -dir)
                    physics.setCarVelocity(0, playerVelocity)

                    physics.engageGear(0, playerGear)
                    physics.setEngineRPM(0, playerRPM)
end
	ui.text("Işınlanacağın Arkadaşını Seç:")
	ui.childWindow("##drivers", vec2(ui.availableSpaceX(), 520), function()
		for i = 1, sim.carsCount - 1 do
			local car = ac.getCar(i)
			local driverName = ac.getDriverName(i)
			--if car.isConnected  then
            if car.isConnected and not car.isAIControlled and not string.find(driverName, "NGG Trafik") then
				if ui.selectable(driverName, selectedCar == car) then
					selectedCar = car
					if Settings.SpectatePlayer == true then
						ac.focusCar(i)
					end
				end
			end
		end
	end)
end




function script.update(dt)
	--#region [Timer]
	if timer.running >= 0 then -- timer for anything to go
		timer.running = timer.running - dt
	end
	--#endregion
end

function script.drawUI()
	if OverlayTimerKey == true then
		ui.transparentWindow("Keyandabindandacooldown", vec2(-15, -5), vec2(150, 150), false, function()
			ui.text("Key: " .. Settings.KeyName .. "\nBekleme Süresi: " .. math.round(timer.running, 1))
		end)
	end
end

ui.registerOnlineExtra(ui.Icons.Compass, "Arkadaşına Işınlan!", nil, Teleportation,nil, ui.OnlineExtraFlags.Tool, ui.WindowFlags.NoScrollWithMouse)
