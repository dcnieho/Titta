function rewarding = provideRewardHelper(rewardProvider,currentlyInArea,forceRewardButton)
persistent forceRewardButtonDown
if isempty(forceRewardButtonDown)
    forceRewardButtonDown = false;
end

rewarding = false;
if ~isempty(rewardProvider)
    [~,~,keyMap] = KbCheck;
    forcedReward = KbMapKey(forceRewardButton,keyMap);
    if currentlyInArea || forcedReward
        rewardProvider.start();
        if forcedReward
            forceRewardButtonDown = true;
        end
        rewarding = true;
    elseif (forceRewardButtonDown && ~forcedReward) || ~currentlyInArea
        rewardProvider.stop();
        forceRewardButtonDown = false;
    end
    rewardProvider.tick();
end