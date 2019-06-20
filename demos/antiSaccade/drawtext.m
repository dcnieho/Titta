function swaptime = drawtext(text, textSetup, w, flipWhen)
drawFormattedText2(w, text, 'center', 'center', textSetup.color, textSetup.wrapAt, textSetup.vSpacing);
swaptime = Screen('Flip',w,flipWhen);