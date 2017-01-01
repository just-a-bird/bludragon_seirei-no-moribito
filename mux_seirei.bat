@echo off
cls
for %%i in (*.mkv) do (
	set src=%%i
	set dest=Edited\%%i
	set name=%%~ni
	set subs=%name%.ass
	set chapters=%name%.xml
	set num=%src:~0,2%
	set title=%name:~5%
	echo %%i
	echo.   src     = %src%
	echo.   dest    = %dest%
	echo.   name    = %name%
	echo.   subs    = %subs%
	echo.   chapter = %chapters%
	echo.   num     = %num%
	echo.   title   = %title%
	echo.
	mkvmerge --ui-language en --output ^"%dest%^" --audio-tracks 1 --no-subtitles --language 1:jpn --track-name ^"1:Dolby Digital 5.1^" --language 4:jpn --track-name ^"4:%num%: %title%^" --default-track 4:yes ^"^(^" ^"%src%^" ^"^)^" --language 0:eng --track-name ^"0:Signs ^& Dialogue ^(SSA^)^" ^"^(^" ^"%subs%^" ^"^)^" --attachment-name Express.ttf --attachment-mime-type application/x-truetype-font --attach-file ^"fonts\Express.ttf^" --attachment-name HoboStd.ttf --attachment-mime-type application/x-truetype-font --attach-file ^"fonts\HoboStd.ttf^" --attachment-name PISAN.TTF --attachment-mime-type application/x-truetype-font --attach-file ^"fonts\PISAN.TTF^" --attachment-name vibrocentric.ttf --attachment-mime-type application/x-truetype-font --attach-file ^"fonts\vibrocentric.ttf^" --chapter-language eng --chapter-charset UTF-8 --chapters ^"%chapters%^" --track-order 0:1,1:0,0:4
)