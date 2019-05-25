%% Import .json data
clear all

histo = webread('https://www.binance.com/api/v1/klines?symbol=BNBUSDT&interval=1m&limit=1000');
%histo = webread('https://min-api.cryptocompare.com/data/histominute?fsym=BNB&tsym=USD&limit=2000');

%% Data cleanup
cc = 5; %Close column
%CryptoCompare API
%Data: time, close, high, low, open, volumefrom, volumeto
%histo = struct2cell(histo.Data)';
%Converting "seconds" date to real date
%histo(:,1) = num2cell(datetime([repmat([1970 1 1 0 0],length(histo),1) [histo{:,1}]' ]));

%Binance API
%Data: time, open, high, low, close, volume, closetime, quote asset volume, number of trades, taker buy base asset volume, taker buy quote asset volume, ignore
for i = 1:length(histo)
	histo(i,1:12) = histo{i,1}';
end
histo(:,[2:6 8 10:12]) = num2cell(str2double(histo(:,[2:6 8 10:12])));
%Converting "seconds" date to real date
histo(:,1) = num2cell(datetime([repmat([1970 1 1 0 0],length(histo),1) [histo{:,1}]'/1000 ]));

%MA_diff adds 3 columns to histo: sma_st, sma_lt, ma_diff
ma_st = 12;
ma_lt = 26;
histo(:,end+1:end+3) = num2cell(zeros(length(histo),3));
for i = ma_st:length(histo)
	if i >= ma_st
		histo{i,end-2} = mean([histo{i-ma_st+1:i,cc}]);
	end
	if i >= ma_lt
		histo{i,end-1} = mean([histo{i-ma_lt+1:i,cc}]);
		histo{i,end} = histo{i,end-2} - histo{i,end-1};
	end
end
ma_col = size(histo,2);

%MACD adds 3 columns to histo: ema_st, ema_lt, macd, signal, difference
macd_st = 12;
macd_lt = 26;
macd_s = 9;
histo(:,end+1:end+5) = num2cell(zeros(length(histo),5));
for i = macd_st:length(histo)
	if i == macd_st
		histo{i,end-4} = mean([histo{i-macd_st+1:i,cc}]);
	elseif i > macd_st
		histo{i,end-4} = (histo{i,cc}-histo{i-1,end-4})*2/(macd_st+1)+histo{i-1,end-4}; %Short term Exponential Moving Average (EMA)
	end
	if i == macd_lt
		histo{i,end-3} = mean([histo{i-macd_lt+1:i,cc}]);
		histo{i,end-2} = histo{i,end-4}-histo{i,end-3};
	elseif i > macd_lt
		histo{i,end-3} = (histo{i,cc}-histo{i-1,end-3})*2/(macd_lt+1)+histo{i-1,end-3}; %Long term Exponential Moving Average (EMA)
		histo{i,end-2} = histo{i,end-4}-histo{i,end-3};
	end
	if i == macd_lt+macd_s-1
		histo{i,end-1} = mean([histo{i-macd_s+1:i,end-2}]);
		histo{i,end} = histo{i,end-2}-histo{i,end-1};
	elseif i > macd_lt+macd_s-1
		histo{i,end-1} = (histo{i,end-2}-histo{i-1,end-1})*2/(macd_s+1)+histo{i-1,end-1}; %Signal line
		histo{i,end} = histo{i,end-2}-histo{i,end-1};
	end
end
macd_col = size(histo,2);

%% Analysis
indicator = macd_col;

status = 1; %0:=usdt, 1:=bnb
start = histo{1,2}; %start price
wallet = 1;
gain = ones(length(histo),2);
fee = 0; %fees in %
for i = macd_lt+macd_s:length(histo)
	if status && histo{i,indicator} < histo{i-1,indicator} && histo{i,indicator} > 0% && histo{i,cc}/start > fee/100
		wallet = wallet*(histo{i,cc}/start-fee/100);
		status = 0;
	elseif ~status && histo{i,indicator} > histo{i-1,indicator} && histo{i,indicator} < 0
		start = histo{i,cc};
		status = 1;
	end
	gain(i) = wallet;
end
fprintf("Final gains: Investment*%.4g\n", gain(end));

history = 0; %Graph history
gains = 1; %Graph gains

start = 0;
finish = 1;
step = 0;
window = 0;

start = max(2,round(start*length(histo)));
finish = min(length(histo),round(finish*length(histo)));

if step == 0
	step = finish-start+1;
end
if window == 0
	window = finish-start-1;
end

for i = start:step:finish
	if history
		figure(1)
		subplot(2,1,1)
		plot([histo{i:i+window,1}],[histo{i:i+window,cc}]);
		subplot(2,1,2)
		positive = [histo{:,indicator}].*([histo{:,indicator}] >= 0);
		negative = [histo{:,indicator}].*([histo{:,indicator}] < 0);
		yyaxis left
		bar([histo{i:i+window,1}], positive(i:i+window), 'g');
		hold on
		bar([histo{i:i+window,1}], negative(i:i+window), 'r');
		hold off
		yyaxis right
		plot([histo{i:i+window,1}],[histo{i:i+window,indicator-2}],'-y')
		hold on
		plot([histo{i:i+window,1}],[histo{i:i+window,indicator-1}],'-m')
		hold off
	end
	if gains
		figure(2)
		plot([histo{i:i+window,1}],gain(i:i+window));
	end
	if step ~= finish-start+1
		pause
	end
end