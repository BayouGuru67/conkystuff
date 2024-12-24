--[[
MIT License

Copyright (c) 2024 JaySam

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]
require'cairo'
require'cairo_xlib'
socket = require'socket'

--vectors contain number of points, then x or y co-ordinates
hx = {6, 0, 5, 20, 25, 20, 5}
hy = {6, 0, 5, 5, 0, -5, -5}

vx = {6, 0, 5, 5, 0, -5, -5}
vy = {6, 0, -5, -20, -25, -20, -5}

colonx = {4, 0, -6, 0, 6}
colony = {4, 0, -6, -12, -6}

--RGB of onoff
rgbOn={26/255, 1, 102/255}
rgbOff={0.3,0.3,0.3}

--on/off for each digit, an array of arrays 0,1,2..9
numbers={ 	{true, true, true, false, true, true, true}, --zero
			{false, false, true, false, false, true, false}, -- one
			{true, false, true, true, true, false, true}, --two
			{true, false, true, true, false, true, true}, --three
			{false, true, true, true, false, true, false}, --four
			{true, true, false, true, false, true, true}, --five
			{true, true, false, true, true, true, true}, --six
			{true, false, true, false, false, true, false}, --seven
			{true, true, true, true, true, true, true}, --eight
			{true, true, true, true, false, true, true} --nine			
		}	

function conky_init(ctrx1, ctry1)
	if conky_window == nil then return end
end




function conky_clock(ctrx, ctry, scale)
	if conky_window == nil then return end
	local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
	cr = cairo_create(cs)
	
	--time
	s = os.date("%S")
	secs=tonumber(s)
	m = os.date("%M")
	mins = tonumber(m)
	h = os.date("%H")
	hours = tonumber(h)
	
	start=0
	spaceBetween=50	
	colonSpaceBetween = 24

	sec1s = secs % 10
	sec10s = secs//10
	min1s = mins % 10
	min10s = mins // 10
	hr1s = hours % 10
	hr10s = hours //10
	isColonOn = ((sec1s % 2) == 0)

	-- hours
	placeNumber(cr, ctrx+(start*spaceBetween), ctry, numbers[hr10s+1], scale)
	start=start+1
	placeNumber(cr, ctrx+(start*spaceBetween), ctry, numbers[hr1s+1], scale)
	start=start+1
	--colon	
	placeColon(cr, ctrx+(start*spaceBetween), ctry, isColonOn, scale)
	--mins
	placeNumber(cr, ctrx+(start*spaceBetween)+colonSpaceBetween, ctry, numbers[min10s+1], scale)
	start=start+1
	placeNumber(cr, ctrx+(start*spaceBetween)+colonSpaceBetween, ctry, numbers[min1s+1], scale)
	start=start+1	
	--colon	
	placeColon(cr, ctrx+(start*spaceBetween)+colonSpaceBetween, ctry, isColonOn, scale)	
	--seconds
	placeNumber(cr,  ctrx+(start*spaceBetween)+2*colonSpaceBetween, ctry, numbers[sec10s+1], scale)
	start=start+1
	placeNumber(cr,  ctrx+(start*spaceBetween)+2*colonSpaceBetween, ctry, numbers[sec1s+1], scale)
	
	start=start+1
	
	--end of output
	cairo_destroy(cr)
	cairo_surface_destroy(cs)
	cr=nil
	return " "
	
end

function placeColon(cr, ctrx, ctry, isOn, scale)
	placeSegment(cr, ctrx, ctry+23, isOn, colonx, colony, scale)
	placeSegment(cr, ctrx, ctry+48, isOn, colonx, colony, scale)
end

function placeNumber(cr, ctrx, ctry, codedNum, scale)
	--offset of segements
	spaceX = 3 
	spaceY = -3  
	scaledVy=vy[5] 
	scaledHx=hx[5] 
	--digits top bar first
	placeSegment(cr, ctrx, ctry, codedNum[1], hx, hy, scale)
	--left down
	placeSegment(cr,ctrx-spaceX, ctry-scaledVy-spaceY, codedNum[2], vx, vy, scale)
	-- right down
	placeSegment(cr,ctrx+scaledHx+spaceX, ctry-scaledVy-spaceY, codedNum[3], vx, vy, scale)
	--middle (must consider existing y space.
	placeSegment(cr,ctrx, ctry-scaledVy-(2*spaceY), codedNum[4], hx, hy, scale)
	--left down from middle
	placeSegment(cr,ctrx-spaceX, ctry-2*(scaledVy) - 3*spaceY, codedNum[5], vx, vy, scale)
	-- right down from middle
	placeSegment(cr,ctrx+scaledHx+spaceX, ctry-2*(scaledVy) - 3*spaceY, codedNum[6], vx, vy, scale)
	-- bottom
	placeSegment(cr,ctrx, ctry-2*(scaledVy+2*spaceY), codedNum[7], hx, hy, scale)
end

function placeSegment(cr, xoffset, yoffset, isOn, vecx, vecy, scale)
	if (isOn) then
		cairo_set_source_rgba (cr,rgbOn[1],rgbOn[2],rgbOn[3],0.7)
	else
		cairo_set_source_rgba (cr,rgbOff[1],rgbOff[2],rgbOff[3],0.2)
	end
	--not the safest, assumes vecx, vecy are equal
	for i=2,(vecx[1]+1) do	
		if (i==2) then
			cairo_move_to (cr, scale*(vecx[i]+xoffset), scale*(vecy[i]+yoffset))
		else
			cairo_line_to (cr, scale*(vecx[i]+xoffset), scale*(vecy[i]+yoffset))
		end
	end

	cairo_close_path (cr)
	cairo_stroke_preserve (cr) 
	cairo_fill(cr)
end



