#include <trade/trade.mqh>

//inputs
input double Lots = 0.1;
input ENUM_TIMEFRAMES tf1 = PERIOD_D1;
input ENUM_TIMEFRAMES tf2 = PERIOD_H4;
input ENUM_TIMEFRAMES tf3 = PERIOD_H1;
input double RRR = 3;//risk reward ratio
input double BE = 1;//sortie break event
input double mult = 2;//risk size
input uint macdLongLen = 26;//taille de la moyenne mobile longue pour le calcul du macd
input uint macdShortLen = 12;//taille de la moyenne mobile courte pour le calcul du macd
input uint macdSignalLen = 9;//taille de la moyenne mobile pour le calcul du signal du macd
input bool macdLowCrossOnly = true;//Open position on low crossover only
input uint maShortPeriod = 20;
input bool maShortEma = false;//la ma courte est une EMA
input uint maLongPeriod = 50;
input uint maStructPeriod = 200;
input bool rsiCondition = true;//prise en compte du RSI
input uint rsiPeriod = 14;
input uint rsiLo = 60;//borne au dessus de la quelle on peut achetter
input uint rsiHi = 80;//borne en dessous de la quelle on peut achetter
input uint maVolumePeriod = 10;
input uint macdEntryTime = 3;//nombre de bougie max pendant pendant les quel un signal d'enter est valide
input bool maConjoncturelCondition = true;//prise en compte de la condition de tendance conjourturelle
input bool maStructurelleCondition = true;//prise en compte de la condition de tendance structurelle
input bool patternCondition = true;//enter uniquement après patern bullish

//Global Variable
CTrade trade;
int handleMACD;
int handleAtr;
int handleVolume;
int handleMA1;
int handleMA2;
int handleMA3;
int handleRSI;
int totalBars = iBars(NULL, tf2);
bool position = false; //position en cours ?
bool achat = false; //entry reason
bool vente = false;//entry reason

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("Init Success");
   
   handleMACD = iCustom(_Symbol,tf2, "gaelM_Indicators\\TrueMACD.ex5", macdLongLen, macdShortLen, macdSignalLen);
   if(maShortEma) handleMA1 = iMA(_Symbol,tf1,maShortPeriod,0,MODE_EMA,PRICE_CLOSE);
   else handleMA1 = iMA(_Symbol,tf1,maShortPeriod,0,MODE_SMA,PRICE_CLOSE);
   handleMA2 = iMA(_Symbol,tf1,maLongPeriod,0,MODE_SMA,PRICE_CLOSE);
   handleMA3 = iMA(_Symbol,tf1,maStructPeriod,0,MODE_SMA,PRICE_CLOSE);
   handleRSI = iRSI(_Symbol,tf1,rsiPeriod,PRICE_CLOSE);
   handleAtr = iATR(_Symbol,tf2,20);
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   int bars = iBars(_Symbol,tf3);
   if(bars > totalBars){
      totalBars = bars;
      //nombre de valeur du macd a prendre en compt
      uint barsToCopy = 4+macdEntryTime-1;
      double macdSignal[];
      ArrayRemove(macdSignal,barsToCopy);
      double macdHisto[];
      ArrayRemove(macdHisto,barsToCopy);
      double maStruct[1];//moyenne mobile structurelle plus long que ma long
      double maLong[1];
      double maShort[1];
      double rsi[1];
      double atr[1];
      CopyBuffer(handleMACD,1,1,barsToCopy,macdSignal);
      CopyBuffer(handleMACD,2,1,barsToCopy,macdHisto);
      CopyBuffer(handleMA1,0,1,1,maShort);
      CopyBuffer(handleMA2,0,1,1,maLong);
      CopyBuffer(handleMA3,0,1,1,maStruct);
      CopyBuffer(handleRSI,0,1,1,rsi);
      CopyBuffer(handleAtr,0,1,1,atr);
      
      //condition de tendance
      //condition sur le RSI
      bool rsiCond = (!rsiCondition)||((rsi[0] >= rsiLo) && (rsi[0] <= rsiHi));
      //condition sur les moyenne mobiles
      bool ConjoncturelCondition = (!maConjoncturelCondition) || (maShort[0] > maLong[0]);
      bool StructurelCondition = (!maStructurelleCondition) || (maLong[0] > maStruct[0]);
      bool trendCondition = rsiCond && ConjoncturelCondition && StructurelCondition;
      
      //condition principale
      //fennêtre de validité du macd
      bool macdCond = false;
      for(uint i=0; i<(macdEntryTime); i++){
         bool candlesAreGreen = true;
         bool histoTurnGreen = (macdHisto[3+i] > 0) && (macdHisto[2+i] < 0) && (macdHisto[1+i] < 0) && (macdHisto[0+i] < 0);
         bool negativeLine = (!macdLowCrossOnly) || ((macdSignal[0+i] < 0) && (macdSignal[1+i] < 0) && (macdSignal[2+i] < 0)/* && (macdSignal[3+i] < 0)*/);
         if(histoTurnGreen && negativeLine){
            for(uint j=(i+1); j<(macdEntryTime); j++){
               candlesAreGreen = candlesAreGreen && (macdHisto[3+j]>macdHisto[3+j-1]);
            }
            macdCond = candlesAreGreen;
         }
         if(macdCond) break;
      }
      
      //pattern condition
      bool patternCondVerifier = false;
      uint lag = 1;
      //on regarde en arrière tant que les bougie sont vertes pour trouver le pattern
      while(iClose(_Symbol,tf3,lag)>iOpen(_Symbol,tf3,lag)){
      // candle -2 is red
      bool redC = iClose(_Symbol,tf3,lag+1)<iOpen(_Symbol,tf3,lag+1);
      // close above pattern
      patternCondVerifier = redC && (iClose(_Symbol,tf3,lag)>iOpen(_Symbol,tf3,lag+1));
      //hammer pattern pour bougie verte
       patternCondVerifier = patternCondVerifier || (((iHigh(_Symbol,tf3,lag)-iLow(_Symbol,tf3,lag))/ (iHigh(_Symbol,tf3,lag)-iOpen(_Symbol,tf3,lag))) > 3);
       if(patternCondVerifier){break;}
       lag++;
      }
      patternCondVerifier = patternCondVerifier || (!patternCondition);
      
      //évaluation de toutes les conditions ensembles
      bool conditionAchat = patternCondVerifier && macdCond && trendCondition;
      if(conditionAchat && !position){
         position = true;
         double entry = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK), _Digits);
         double tp = entry + mult*RRR*atr[0];
         double sl = entry - mult*atr[0]-(entry-iLow(_Symbol,tf2,1));
         trade.Buy(Lots,NULL,entry,sl,tp,"Achat");
      }
      if(! PositionSelect(_Symbol)){
         position = false;
         }
   }
   
  }