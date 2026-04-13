function p = pi_leibniz(n)
	s = 0;
	for k = 0:n
		s = s + ((-1)^k)/(2*k + 1);
	endfor
	p = s*4;
endfunction
