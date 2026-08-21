--[[
    Player Media section for YouTube Player By L
    Returns install(ytPanel, ytStatus, YouTubeAPI, StarterGui)
]]

return function(ytPanel, ytStatus, YouTubeAPI, StarterGui)
    if not ytPanel or not YouTubeAPI then return end

    -- Enlarge panel slightly for the new section
    ytPanel.Size = UDim2.new(0, 340, 0, 560)
    ytPanel.Position = UDim2.new(0.5, -170, 0.5, -280)

    local sectionY = 148

    -- If search area exists, push it down
    local playerArea = ytPanel:FindFirstChild("PlayerArea")
    if playerArea then
        playerArea.Position = UDim2.new(0, 8, 0, 320)
        playerArea.Size = UDim2.new(1, -16, 1, -328)
    end

    local label = Instance.new("TextLabel")
    label.Name = "PlayerMediaLabel"
    label.Size = UDim2.new(1, -28, 0, 18)
    label.Position = UDim2.new(0, 14, 0, sectionY)
    label.BackgroundTransparency = 1
    label.Text = "Player Media"
    label.TextColor3 = Color3.fromRGB(255, 80, 80)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = ytPanel

    local urlBox = Instance.new("TextBox")
    urlBox.Name = "PlaceUrlBox"
    urlBox.Size = UDim2.new(1, -28, 0, 34)
    urlBox.Position = UDim2.new(0, 14, 0, sectionY + 22)
    urlBox.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    urlBox.PlaceholderText = "Place URL"
    urlBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
    urlBox.TextColor3 = Color3.fromRGB(220, 220, 220)
    urlBox.Font = Enum.Font.Gotham
    urlBox.TextSize = 13
    urlBox.ClearTextOnFocus = false
    urlBox.TextXAlignment = Enum.TextXAlignment.Left
    urlBox.Text = ""
    urlBox.Parent = ytPanel
    Instance.new("UIPadding", urlBox).PaddingLeft = UDim.new(0, 10)
    Instance.new("UICorner", urlBox).CornerRadius = UDim.new(0, 8)

    local applyUrl = Instance.new("TextButton")
    applyUrl.Name = "ApplyUrlButton"
    applyUrl.Size = UDim2.new(1, -28, 0, 32)
    applyUrl.Position = UDim2.new(0, 14, 0, sectionY + 62)
    applyUrl.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    applyUrl.Text = "Apply"
    applyUrl.TextColor3 = Color3.fromRGB(255, 255, 255)
    applyUrl.Font = Enum.Font.GothamBold
    applyUrl.TextSize = 14
    applyUrl.AutoButtonColor = false
    applyUrl.Parent = ytPanel
    Instance.new("UICorner", applyUrl).CornerRadius = UDim.new(0, 8)

    -- Media player card (hidden until valid URL)
    local mediaCard = Instance.new("Frame")
    mediaCard.Name = "MediaPlayer"
    mediaCard.Size = UDim2.new(1, -28, 0, 0)
    mediaCard.Position = UDim2.new(0, 14, 0, sectionY + 102)
    mediaCard.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    mediaCard.BorderSizePixel = 0
    mediaCard.ClipsDescendants = true
    mediaCard.Visible = false
    mediaCard.Parent = ytPanel
    Instance.new("UICorner", mediaCard).CornerRadius = UDim.new(0, 10)

    local thumb = Instance.new("ImageLabel")
    thumb.Name = "Thumbnail"
    thumb.Size = UDim2.new(1, -16, 0, 160)
    thumb.Position = UDim2.new(0, 8, 0, 8)
    thumb.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    thumb.BorderSizePixel = 0
    thumb.ScaleType = Enum.ScaleType.Crop
    thumb.Parent = mediaCard
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(0, 8)

    local playOverlay = Instance.new("TextLabel")
    playOverlay.Size = UDim2.new(0, 48, 0, 48)
    playOverlay.Position = UDim2.new(0.5, -24, 0.5, -24)
    playOverlay.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    playOverlay.BackgroundTransparency = 0.2
    playOverlay.Text = "▶"
    playOverlay.TextColor3 = Color3.fromRGB(255, 255, 255)
    playOverlay.Font = Enum.Font.GothamBold
    playOverlay.TextSize = 22
    playOverlay.Parent = thumb
    Instance.new("UICorner", playOverlay).CornerRadius = UDim.new(1, 0)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Name = "Title"
    titleLbl.Size = UDim2.new(1, -16, 0, 36)
    titleLbl.Position = UDim2.new(0, 8, 0, 174)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = ""
    titleLbl.TextColor3 = Color3.fromRGB(230, 230, 230)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 13
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextYAlignment = Enum.TextYAlignment.Top
    titleLbl.TextWrapped = true
    titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
    titleLbl.Parent = mediaCard

    local authorLbl = Instance.new("TextLabel")
    authorLbl.Name = "Author"
    authorLbl.Size = UDim2.new(1, -16, 0, 16)
    authorLbl.Position = UDim2.new(0, 8, 0, 210)
    authorLbl.BackgroundTransparency = 1
    authorLbl.Text = ""
    authorLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
    authorLbl.Font = Enum.Font.Gotham
    authorLbl.TextSize = 11
    authorLbl.TextXAlignment = Enum.TextXAlignment.Left
    authorLbl.TextTruncate = Enum.TextTruncate.AtEnd
    authorLbl.Parent = mediaCard

    local openBtn = Instance.new("TextButton")
    openBtn.Name = "OpenVideo"
    openBtn.Size = UDim2.new(1, -16, 0, 30)
    openBtn.Position = UDim2.new(0, 8, 0, 232)
    openBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    openBtn.Text = "Open Video"
    openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    openBtn.Font = Enum.Font.GothamBold
    openBtn.TextSize = 13
    openBtn.AutoButtonColor = false
    openBtn.Parent = mediaCard
    Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 8)

    local currentVideoId = nil
    local currentWatchUrl = nil

    openBtn.MouseButton1Click:Connect(function()
        if not currentWatchUrl then return end
        local copied = false
        pcall(function() if setclipboard then setclipboard(currentWatchUrl) copied = true end end)
        pcall(function() if toclipboard then toclipboard(currentWatchUrl) copied = true end end)
        if StarterGui then
            StarterGui:SetCore("SendNotification", {
                Title = "YouTube Player By L",
                Text = copied and "Link copied to clipboard" or currentWatchUrl,
                Duration = 4,
            })
        end
    end)

    local function showMedia(videoId, meta)
        currentVideoId = videoId
        currentWatchUrl = "https://www.youtube.com/watch?v=" .. videoId

        thumb.Image = (meta and meta.thumbnail_url) or YouTubeAPI.thumbnailForId(videoId) or ""
        titleLbl.Text = (meta and meta.title) or ("Video " .. videoId)
        authorLbl.Text = (meta and meta.author_name) or "YouTube"

        mediaCard.Visible = true
        mediaCard.Size = UDim2.new(1, -28, 0, 270)

        if ytStatus then
            ytStatus.Text = "Loaded: " .. (titleLbl.Text:sub(1, 40))
            ytStatus.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
    end

    local function hideMedia()
        mediaCard.Visible = false
        mediaCard.Size = UDim2.new(1, -28, 0, 0)
        currentVideoId = nil
        currentWatchUrl = nil
    end

    applyUrl.MouseButton1Click:Connect(function()
        local raw = urlBox.Text
        local videoId = YouTubeAPI.extractVideoId(raw)

        if not videoId then
            hideMedia()
            if ytStatus then
                ytStatus.Text = "Invalid YouTube URL"
                ytStatus.TextColor3 = Color3.fromRGB(220, 80, 80)
            end
            return
        end

        if ytStatus then
            ytStatus.Text = "Loading video…"
            ytStatus.TextColor3 = Color3.fromRGB(200, 200, 100)
        end
        applyUrl.Text = "…"
        applyUrl.Active = false

        task.spawn(function()
            local meta, err = YouTubeAPI.fetchOEmbed(videoId)
            applyUrl.Text = "Apply"
            applyUrl.Active = true

            if not meta then
                -- Still show player with thumbnail CDN even if oEmbed fails
                showMedia(videoId, {
                    title = "YouTube Video",
                    author_name = videoId,
                    thumbnail_url = YouTubeAPI.thumbnailForId(videoId),
                })
                if ytStatus and err then
                    ytStatus.Text = "Loaded (limited info) · " .. tostring(err)
                    ytStatus.TextColor3 = Color3.fromRGB(200, 180, 80)
                end
                return
            end

            showMedia(videoId, meta)
        end)
    end)
end
