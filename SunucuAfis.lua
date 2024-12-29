local screensize = vec2(ac.getSim().windowWidth,ac.getSim().windowHeight)
local hideImage = false -- Yeni değişken: Görselin saklanıp saklanmadığını kontrol eder.

--image_0 is used as the rules splash screen
local image_0 = {
    ['src'] = 'https://cdn.numiezganggarage.com.tr/scripts/SunucuAfisi.png',
    ['sizeX'] = 1920, --size of your image in pixels
    ['sizeY'] = 1080, --size of your image in pixels
    ['paddingX'] = screensize.x/2-1920/2, --this makes it sit in the centre of the screen
    ['paddingY'] = 150 --this moves it up 50 pixels
}

--image_1 is used as the icon
local image_1 = {
    ['src'] = 'https://cdn.numiezganggarage.com.tr/NggLogo.png',
    ['sizeX'] = 138,
    ['sizeY'] = 138,
    ['paddingX'] = 50, --use this to align it, currently 50 pixels from top right
    ['paddingY'] = 50 --use this to align it, currently 50 pixels from top right
}

--this waits for the driver to not be in the setup screen, then handles the key press
function script.update(dt)
    ac.debug('isInMainMenu', ac.getSim().isInMainMenu)

    -- "H" tuşuna basılırsa görseli sakla
    if ac.isKeyDown(ac.KeyIndex.Tab) or ac.isKeyDown(ac.KeyIndex.H) then
        hideImage = true
    end
end

--this draws the splash screen then after draws the icon
function script.drawUI()
    if not hideImage and not ac.getSim().isInMainMenu then
        ac.log("Rules Displayed")
        ui.drawImage(image_0.src, vec2(image_0.paddingX, screensize.y-image_0.sizeY-image_0.paddingY), vec2(image_0.sizeX+image_0.paddingX, screensize.y-image_0.paddingY), true)
    end
    if hideImage and not ac.getSim().isInMainMenu then
        ac.log("Icon Active")
        ui.drawImage(image_1.src, vec2(image_1.paddingX, image_1.paddingY), vec2(image_1.sizeX+image_1.paddingX, image_1.sizeY+image_1.paddingY), true)
    end
end
