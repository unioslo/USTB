close all;
clear all;

%% Task 1a)
% Q: What happens when we make x_row, x_col, x1, x2, and x3?

x_row = 0 : 2 : 6;
x_col = x_row.'; % flips from row to column (and column to row)

x1 = [1,2,3];
x2 = [1;2;3];
x3 = linspace(1,10,4);

%% Task 1b)
% Q: What is the difference?
a = x_row * x_col;
b = x_col * x_row;
c = x_row .* x_col;
d = x_row .* x_col';
e = x_row' .* x_col;

%% Task 1c)
% Q: What happens here?

z_row = x_row + 2j*x_row;

%% Task 1d)
% Q: What happens, and why is there a difference?

z_col1 = z_row'; % this is called "transpose"
z_col2 = z_row.'; % this is called "ctranspose"

figure(1); hold on; xlabel('real'); ylabel('imag')
plot(real(z_col1), imag(z_col1),'r-o', 'Displayname','z_{col1}')
plot(real(z_col2), imag(z_col2),'b-o', 'Displayname','z_{col2}')
legend


%% Task 2a)
% Q: This is one way to make a matrix. Give examples of other methods to 
%    make a 5x5 matrix and a 2x3 matrix with optional entires. 

A = nan(3,3);
A(1,:) = [1,1,1];
A(2,:) = [2,2,2];
A(3,:) = [3,3,3];

%% Task 2b)
% Q: How does this multidimensional array look, and why?
%    Can we "plot" B? Why not?
%    What does size(B) tell us?
B = repmat(A,[2 1 2]);

%% Task 2c)
% Q: What is the difference?
sum1 = sum(B);
sum2 = sum(B,2);
sum3 = sum(B,3);
sum4 = sum(B, 'all');
sum5 = sum(sum(sum(B)));

%% Task 2d)
% Q: size(sum1) = 1 3 2. Explain what a "singleton dimension" is and
%    what the function "squeeze" does.
sum1_squeezed = squeeze(sum1);
