function p = pi_montecarlo(n, x, y)
	h = 0;
	for i = 1:n
		xv = x(i);
		yv = y(i);
		if (xv*xv + yv*yv < 1)
			h = h + 1;
		endif
	endfor
	p = 4*h/n;
endfunction
