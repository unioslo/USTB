# Module 1 Introduction to MATLAB and USTB

This module contains two exercises. The first is to familiarize ourselves with some MATLAB concepts that will come in handy later in the course, and the second is to set up the USTB.

## Delivery:
Please provide a written report that

- report the results you are asked to find
- answers the question raised
- provides the main code lines needed to solve the questions directly in the report
- all plots needed for supporting your arguments when answering the exercise parts

The report should be uploaded to [devilry.ifi.uio.no](devilry.ifi.uio.no).  
**Deadline for uploading: Tuesday 6. September at 10:00. **

## Exercise One MATLAB:
This exercise will only go into a few of the details of MATLAB programming, and it is wise to use
this opportunity to verify and/or learn what you need in order to be comfortable with basic scientific
programming in MATLAB.

The best tip in general is to use the internet actively to find what you need. This includes YouTube, 
StackOverflow, and notably the documentation provided by MathWorks (the company behind MATLAB). It is
 well worth spending some time getting familiar with how functions (e.g., [sum] (https://se.mathworks.com/help/matlab/ref/sum.html) are documented.

The experience from earlier years in IN3015/IN4015 is that students have varied backgrounds. Ideally you should know a
programming language already, and for many this will be Python. The scientific stack in Python includes Numpy and 
Scipy, which is very similar to MATLAB. Two relevant resources for those with a Python background are 
[Numpy for Matlab users] (https://numpy.org/doc/stable/user/numpy-for-matlab-users.html) 
or [Matlab for Python users] at (https://blogs.mathworks.com/student-lounge/2021/02/19/introduction-to-matlab-for-python-users/)

MathWorks have a lot of official resources, for instance this [getting started page] (https://se.mathworks.com/help/matlab/getting-started-with-matlab.html)
An alternative is the onramp tutorial that starts from the very basics, and lets you program interactively in the web browser. Note that you do need to be logged in:
(https://matlabacademy.mathworks.com/details/matlab-onramp/gettingstarted)

### Within MATLAB:

In Fig.~\ref{fig:window} we can see the MATLAB user interface. The left pane is the current folder which shows us what files MATLAB has access to.
One of these functions is the test\_function.m that is also shown in the editor. This function takes in a number $x$, and returns a complex number $x+2ix$. The ``command window'' allows us to run this function, and we assign the output to the variable \texttt{a}. This variable is now known to MATLAB as we can see it in the ``workspace'', but when we can use it depends on the \textit{scope} (scope determines where in your program a name is visible).

![Scheme](window.png)

In many cases, such as when we are working with USTB, our functions are not located in our current folder. We then need to make sure the functions are on the 
MATLAB path. MATLAB uses the search path to locate files in the system. You can include folders from anywhere to the path by navigating to them, right-clicking,
and selecting add to path, or by using the \texttt{addpath} function.


## TASKS
In the Matlab_intro.m file, you will find sections of code (separated by \texttt{\%\%}) that can be run individually. Run the code and answer the questions in the file.

### Hints: 1) Arrays - lists of numbers}

\textbf{a)} In MATLAB 1D-arrays are either row (lying) or column (standing) vectors. Type \texttt{x\_row} into the command window and press enter. What about \texttt{x\_col}?

\textbf{b)} The fact that MATLAB separates between row and column vectors makes it important to be aware of pitfalls when, e.g., multiplying two arrays together. How well do you remember your linear algebra? Some combinations output a matrix! Keywords: inner product (dot product), outer product (sometimes: tensor product), element-wise product (Hadamard product).

\textbf{c)} If you multiply an array with a complex number, all entries are also multiplied.

\textbf{d)} In MATLAB there is a difference between the transpose and the conjugate transpose. This can be hard to debug if you get it wrong the first time!



\subsection*{Hints: 2) Multidimensional arrays}

In the next few modules we will find that the datasets in ultrasound imaging are multidimensional: (time x elements x transmit direction). This is one more dimension than matrices and therefore harder to visualize.

\textbf{a)} Matrices can be composed as rows of columns, or columns as rows (remember the difference between commas ``,'' and semicolons ``;''). However, there are other methods that are often employed for structured matrices such as \texttt{ones()}, \texttt{eye()}, \texttt{magic()}, \texttt{diag()}.

\textbf{b)} In addition to using \texttt{size()} it is often useful to inspect the object or variable in the workspace. Double click on \texttt{B} to get a more detailed view.

\textbf{c)} Looking at the documentation is always useful: \url{https://se.mathworks.com/help/matlab/ref/sum.html}.

\textbf{d)} No hints here.

\subsection*{Hits: 3) Indexing}

\subsection*{Exercise 4) Install and run The UltraSound ToolBox}

See the readme.md in this folder.


\section*{Other tips / optional}

\texttt{ginput(n)} - This function lets you identify the coordinates of $n$ points in a plot with the cursor. Try to calculate the period of the sinusoid. Can you get close to $T=3$?
\begin{lstlisting}
    x = 0:0.1:10;
    T = 3;
    y = sin(2*pi/T*x);
    plot(x,y); ylim([-2,2]); xlabel('x'); ylabel('y');
    [px, py] = ginput(2);
    disp( abs(px(2)-px(1)) )
\end{lstlisting}

At some point you will certainly run into bugs that are hard to fix. Learning to use MATLABs debug tools are very helpful. Writing \texttt{dbstop if error} is one way to set breakpoint when something goes awry. In nested function calls it can be difficult to asses why an error is raised, but from the toolbar during debug mode you can always access any layer of the ``Function Call Stack''. Write code that raises an error, and see if you can find the bug using the built-in tools.

\end{document}
