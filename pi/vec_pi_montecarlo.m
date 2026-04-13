function p = vec_pi_montecarlo(n, x, y)
	h = sum(x.*x + y.*y < 1);
	p = 4*h/n;
endfunction
