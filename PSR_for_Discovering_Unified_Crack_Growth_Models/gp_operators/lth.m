function y = lth(a,b)
%LTH Node. Less than operator
%
%   Performs an element by element comparison of A and B and returns
%   1 if A(i) < B(i) and 0 otherwise.
%
%   (c) Dominic Searson 2009-2015
%   Copyright (c) 2023-2025 Chaoyang Wang
%   GPTIPS 2
%
%   See also GTH, STEP, THRESH, IFLTE, MINX, MAXX, NEG, GPAND, GPNOT, GPOR

y = double(lt(a,b));