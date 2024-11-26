function draw_sample(wpnt, x, y, gazeClr, gazeRadius)
rect = CenterRectOnPointd([0 0 2 2]*gazeRadius,x,y);
Screen('FrameOval', wpnt, gazeClr, rect, 5);