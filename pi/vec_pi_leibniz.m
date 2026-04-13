function p = vec_pi_leibniz(n)
	k = 0:n;
	p = 4 * sum(((-1).^k) ./ (2*k + 1));
endfunction
