close all;
clear all;

%% Task 1a)
% Q: What happens when we make x_row, x_col, x1, x2, and x3?

% HINT: In MATLAB 1D-arrays are either row (lying) or column (standing) vectors. Type x_row into the command window and press enter. What about x_col?

x_row = 0 : 2 : 6;
x_col = x_row.'; % flips from row to column (and column to row)

x1 = [1,2,3];
x2 = [1;2;3];
x3 = linspace(1,10,4);

%% Task 1b)
% Q: What is the difference?

% HINT: The fact that MATLAB separates between row and column vectors makes it important to be aware of pitfalls when, e.g., multiplying two arrays together. 
% How well do you remember your linear algebra? Some combinations output a matrix! 
% Keywords: inner product (dot product), outer product (sometimes: tensor product), element-wise product (Hadamard product).

a = x_row * x_col;
b = x_col * x_row;
c = x_row .* x_col;
d = x_row .* x_col';
e = x_row' .* x_col;

%% Task 1c)
% Q: What happens here?

% HINT: If you multiply an array with a complex number, all entries are also multiplied.

z_row = x_row + 2j*x_row;

%% Task 1d)
% Q: What happens, and why is there a difference?

% HINT: In MATLAB there is a difference between the transpose and the conjugate transpose. This can be hard to debug if you get it wrong the first time!

z_col1 = z_row'; % this is called "transpose"
z_col2 = z_row.'; % this is called "ctranspose"

figure(1); hold on; xlabel('real'); ylabel('imag')
plot(real(z_col1), imag(z_col1),'r-o', 'Displayname','z_{col1}')
plot(real(z_col2), imag(z_col2),'b-o', 'Displayname','z_{col2}')
legend


%% Task 2a)
% Q: This is one way to make a matrix. Give examples of other methods to 
%    make a 5x5 matrix and a 2x3 matrix with optional entires. 

% HINT: Matrices can be composed as rows of columns, or columns as rows (remember the difference between commas , and semicolons ;). 
% However, there are other methods that are often employed for structured matrices such as: ones(), eye(), magic(), diag().

A = nan(3,3);
A(1,:) = [1,1,1];
A(2,:) = [2,2,2];
A(3,:) = [3,3,3];

%% Task 2b)
% Q: How does this multidimensional array look, and why?
%    Can we "plot" B? How / why / why not?
%    What does size(B) tell us?

% HINT: In the next few modules we will find that the datasets in ultrasound imaging are multidimensional: (time x elements x transmit direction). This is one more dimension than matrices.
% In addition to using size() it is often useful to inspect the object or
% variable in the workspace. Try to double click on B to get a more detailed view once this section has been run.

B = repmat(A,[2 1 2]);

%% Task 2c)
% Q: What is the difference?

% HINT: Looking at the documentation is always useful: https://se.mathworks.com/help/matlab/ref/sum.html

sum1 = sum(B);
sum2 = sum(B,2);
sum3 = sum(B,3);
sum4 = sum(B, 'all');
sum5 = sum(sum(sum(B)));

%% Task 2d)
% Q: size(sum1) = 1 3 2. Explain what a "singleton dimension" is and
%    what the function "squeeze" does.

% No hints here :)

sum1_squeezed = squeeze(sum1);

%% OPTIONAL
% ginput(n) - This function lets you identify the coordinates of n points in a plot with the cursor. 
% Try to calculate the period of the sinusoid. Can you get close to T=3?

x = 0:0.1:10;
T = 3;
y = sin(2*pi/T*x);
plot(x,y); ylim([-2,2]); xlabel('x'); ylabel('y');
[px, py] = ginput(2);
disp( abs(px(2)-px(1)) )
