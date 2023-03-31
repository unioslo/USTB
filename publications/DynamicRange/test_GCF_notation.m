%Create a signal
s = [1 2 3 4 5 4 3 2 1 2]+1i*[3 4 5 4 3 2 1 2 1 2];

% Implement with the DFT as written in the article
% NB, only for the "low frequency" region -M0:M0
M = length(s);
idx = 1;
M0 = 3;
P = zeros(1,length(-M0:M0));
S = zeros(1,length(-M0:M0));
tic
for n = -M0:M0
    for m = 1:M
       P(idx) =  P(idx) + exp(-j*pi*(n))*s(m)*exp(-j*2*pi*(m-1)*(n)/M);
       S(idx) =  S(idx) + s(m)*exp(-j*2*pi*(m-1-M/2)*(n)/M);
    end
    idx = idx + 1
end

S_alt_1 = zeros(1,M);
idx = 1;
for n = 0:M-1
    for m = 1:M
       S_alt_1(idx) =  S_alt_1(idx) + s(m)*exp(-j*2*pi*(m-1-M/2)*(n)/M);
    end
    idx = idx + 1
end

S_alt_2 = zeros(1,M);
idx = 1;
for n = -M/2:M/2-1
    for m = 1:M
       S_alt_2(idx) =  S_alt_2(idx) + s(m)*exp(-j*2*pi*(m-1-M/2)*(n)/M);
    end
    idx = idx + 1
end

toc

figure(1);clf
subplot(311);
plot(-M0:M0,abs(P));hold on;
plot(-M0:M0,abs(S),'b*');
title(['The low frequency region M0 = ',num2str(M0)]);
subplot(312)
plot(0:M-1,abs(S_alt_1));hold on;
plot(-M/2:M/2-1,abs(S_alt_2),'b*');
plot(0:M-1,abs(fft(s)),'ro');
subplot(313)
plot(-M0:M0,abs(S_alt_1([M-M0+1:M 1:M0+1])));hold on;
plot(-M0:M0,abs(S_alt_2([end/2-M0+1:end/2+M0+1])),'b*');
S_fft = fftshift(abs(fft(s)));
plot(-M0:M0,S_fft([end/2-M0+1:end/2+M0+1]),'ro');
%%
tic
fft(s);
toc

%Plot the FFT and the shifted FFT
figure(2);clf
subplot(211);hold all;
plot(linspace(0,M-1,M),abs(fft(s)));
plot([M0 M0],[0 20],'r');
plot([M-M0 M-M0],[0 20],'r');
title('FFT');
subplot(212)
plot(abs(fftshift(fft(s))))
title('fftshifted FFT');

[0:M0 M-M0:M-1]

figure(3);clf;
subplot(211);
plot(-M0:M0,abs(P));
title(['The low frequency region from -M0 to M0']);
subplot(212);hold on;
plot(linspace(0,M-1,M),abs(fft(s)));
plot([M0 M0],[0 20],'r');
plot([M-M0 M-M0],[0 20],'r');
title(['The low frequency region from 0 to M0 and M-M0 to M-1']);