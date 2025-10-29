//+------------------------------------------------------------------+
//|                                                    ThreeBars.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#define SHOW_WARNINGS
#define WARNING Print

#include <My/Trade/MqlTradeSync.mqh>
#include <My/Monitors/SymbolMonitor.mqh>
#include <My/Monitors/TradeState.mqh>
#include <My/Monitors/PositionFilter.mqh>
#include <My/Monitors/PositionMonitor.mqh>
#include <My/Utils/AutoPtr.mqh>

const input long gMagic = 123456789; //Идентификатор робота;

//+------------------------------------------------------------------+
//| Input Setting patams                                             |
//+------------------------------------------------------------------+
input group "TRADE TIME SETTINGS"
input bool iEnable = false;   //Включить торговлю по времени
input int iStartHour = 8;     //Начало торговли (час с 0..23)
input int iEndHour = 18;      //Конец торговли (час с 0...23)

input group "SYMBOL SETTINGS"
input int iBars = 3;            //Количество баров подряд
input float iLot = 0.01f;       //Торговый лот
input int iMaxDiviation = 100;  //Максимальное отклонение от цены в пунктах
input int iSkipSecOnError = 1;  //Время между повоторными попытками отправить торговый приказ при ошибке (сек)
input bool iTickwise = false;    //Выполнять расчёт на каждом тике?

/**
 * Тип торгового сигнала
 */
enum TRADE_SIGNAL {
  SELL = -1, //Сигнал на продажу
  NONE = 0,  //Нет торгового сигнала
  BUY = 1    //Сигнал на покупку
};

/**
 * Параметры времени для торговли
 */
struct TradeTime
{ 
  bool enable;
  uint startHour; //0..23
  uint endHour;   //0..23

  bool isTradeTime(datetime now) {
    if (!enable) {
      return false;
    }
    long hour = (now % (60 * 60 * 24)) / (60 * 60);
    //c 9:00 до 20:00
    if(startHour < endHour)
    {
       return hour >= startHour && hour < endHour;
    }
    //c 18:00 до 01:00
    else
    {
       return hour >= startHour || hour < endHour;
    }
  }
};

/**
 * Настройки для работы стратегии
 */ 
struct Settings {
  string symbol;
  double lot;
  TradeTime tradeTime;
  long skipTimeOnError;
  int bars;
  int maxDiviation;
  bool tickwise;

  void defaults() {
    symbol = _Symbol;
    bars = 3;
    lot = 0.01;
    maxDiviation = 100;
    skipTimeOnError = 0;
    tickwise = false;
    tradeTime.enable = false;
    tradeTime.startHour = 0;
    tradeTime.endHour = 0;
  }

  /**
   * Валидация входных параметров настроек
   * @return true - всё супер, false - что-то не так
   */
  bool validate() {
    bool validate = true;
    SymbolMonitor sm(symbol);

    if ((sm.get(SYMBOL_TRADE_MODE) & SYMBOL_TRADE_MODE_FULL) == 0) {
      Print("По символу: ", symbol, " торговля запрещена. ", "TradeMode: ", sm.get(SYMBOL_TRADE_MODE));
      validate = false;
    }

    // Print("SYMBOL_FILLING_MODE: ", sm.get(SYMBOL_FILLING_MODE), " ORDER_FILLING_FOK: ", (string)((int)ORDER_FILLING_FOK));

    // if ((sm.get(SYMBOL_FILLING_MODE) & ORDER_FILLING_FOK) == 0) {
    //   Print("По символу: ", symbol, " неверная политика заполнения объема. ", "FillingMode: ", sm.get(SYMBOL_FILLING_MODE));
    //   validate = false;
    // }
    
    int orderMode = (int)sm.get(SYMBOL_ORDER_MODE);
    if ((orderMode & SYMBOL_ORDER_MARKET) == 0) {
      Print("По символу: ", symbol, " запрещены рыночные ордера. ", "OrderMode: ", sm.get(SYMBOL_ORDER_MODE));
      validate = false;
    }

    if ((orderMode & SYMBOL_ORDER_SL) == 0) {
      Print("По символу: ", symbol, " запрещены стоп уровни. ", "OrderMode: ", sm.get(SYMBOL_FILLING_MODE));
      validate = false;
    }

    if ((orderMode & SYMBOL_ORDER_TP) == 0) {
      Print("По символу: ", symbol, " Запращены уровни прибыли. ", "OrderMode: ", sm.get(SYMBOL_FILLING_MODE));
      validate = false;
    }

    return validate;
  }
};

class SeveralBars {
//Если 3 свечи одного цвета, то открываем в противоположную сторону позицию, открытие на начале новой свечи
//Стоп за звост + фильтр
//Тэйк за тело самой прибыльной
  Settings settings;
  datetime lastRead;      // Последнее время считывания значения
  bool tickwise;          // Работа по тикам (true) или по барам (false)
  TradeTime tradeTime;    // Праметры времени торговли
  datetime badConditions; // Время плохих условий
  datetime lastTradeBar;
  SymbolMonitor mSymbol;

  AutoPtr<PositionState> position;

  public:
    SeveralBars(Settings &s) : mSymbol(settings.symbol) {
      settings = s;
      lastRead = 0;
      tickwise = s.tickwise;

      PositionFilter f;
      ulong tickets[];
      f.let(POSITION_MAGIC, gMagic).let(POSITION_SYMBOL, settings.symbol)
      .select(tickets);

      int posCount = ArraySize(tickets);

      if (posCount > 1) {
        closeOldestPositions(tickets);
      }
      else if (posCount > 0) {
        position = new PositionState(tickets[0]);
      }
    }

    bool trade() {
      if (settings.skipTimeOnError > 0 &&
        badConditions == TimeCurrent() / settings.skipTimeOnError * settings.skipTimeOnError) {
        Print("Время торговли после ошибки ещё не наступило");
        return false;
       }
      
      if (tradeTime.enable && !tradeTime.isTradeTime(TimeCurrent())) {
        //Закрывать позиции?
        return false;
      }

      if (isNewTime()) {
        Print("Новая проверка");
        TRADE_SIGNAL signal = getSignal();

        switch (signal) {
        case BUY:
          if (position[] && position[].refresh()) {
            position[].update();
            long type = position[].get(POSITION_TYPE);

            if (type == POSITION_TYPE_SELL) {
              if (close(position[].get(POSITION_TICKET))) {
                position = NULL;

                ulong ticket = openBuy();
                if (ticket > 0) {
                  position = new PositionState(ticket);
                } else {
                  return false;
                }
              } else {
                position[].refresh();
                return false;
              }
            }
          }
          else {
            ulong ticket = openBuy();
            if (ticket > 0) {
              position = new PositionState(ticket);
            } else {
              return false;
            }
          }
          break;

        case SELL:
          if (position[] && position[].refresh()) {
            position[].update();
            long type = position[].get(POSITION_TYPE);

            if (type == POSITION_TYPE_BUY) {
              if (close(position[].get(POSITION_TICKET))) {
                position = NULL;

                ulong ticket = openSell();
                if (ticket > 0) {
                  position = new PositionState(ticket);
                } else {
                  return false;
                }
              } else {
                position[].refresh();
                return false;
              }
            }
          }
          else {
            ulong ticket = openSell();
            if (ticket > 0) {
              position = new PositionState(ticket);
            } else {
              return false;
            }
          }
          break;

        default:
          break;
        }
      }

      lastRead = lastTime();
      Print(lastRead);
      return true;
    }

    /**
     * Проверка наличия сигнала для совершения операции
     */
    TRADE_SIGNAL getSignal() {
      double opens[];
      double closes[];

      if (CopySeries(settings.symbol, PERIOD_CURRENT, 1, settings.bars, COPY_RATES_OPEN | COPY_RATES_CLOSE, opens, closes) > -1) {
         int whiteCnt = 0;
         int blackCnt = 0;

         for (int i = 0; i < settings.bars; i++) {
           if (opens[i] > closes[i]) blackCnt++;
           else if (opens[i] < closes[i]) whiteCnt++;
         }
         
         if (whiteCnt == settings.bars) return SELL;
         if (blackCnt == settings.bars) return BUY;

      } else {
        Print("Не удалось получить информацию о барах от сервера: ", GetLastError());
      }

      return NONE;
    }

    /**
     * Проверяет настало ли время произвести новый расчёт
    */
    bool isNewTime()
    {
      return lastRead != lastTime();
    }

    /**
     * Время для расчёта в зависимости от выбранной стратегии
    */
    datetime lastTime()
    {
      return tickwise ? TimeTradeServer() : iTime(_Symbol, _Period, 0);
    }

    ulong openBuy() {
      if (lastTradeBar == iTime(settings.symbol, PERIOD_CURRENT, 0)) return 0;
      double price = mSymbol.get(SYMBOL_ASK);

      if (!checkFreeMargin(ORDER_TYPE_BUY, price)) return 0;
      MqlTradeRequestSync request;
      prepare(request);

      if(request.buy(settings.symbol, settings.lot, price, getSL(ORDER_TYPE_BUY), getTP(ORDER_TYPE_BUY))) {
        ulong ticket = postprocess(request);
        if (ticket > 0) lastTradeBar = iTime(settings.symbol, PERIOD_CURRENT, 0);
        return postprocess(request);
      }

      return 0;
    }

    ulong openSell() {
      if (lastTradeBar == iTime(settings.symbol, PERIOD_CURRENT, 0)) return 0;
      double price = mSymbol.get(SYMBOL_BID);

      if (!checkFreeMargin(ORDER_TYPE_SELL, price)) return 0;
      MqlTradeRequestSync request;
      prepare(request);

      if(request.sell(settings.symbol, settings.lot, price, getSL(ORDER_TYPE_SELL), getTP(ORDER_TYPE_SELL))) {
        ulong ticket = postprocess(request);
        if (ticket > 0) lastTradeBar = iTime(settings.symbol, PERIOD_CURRENT, 0);

        return ticket;
      }

      return 0;
    }

    bool checkFreeMargin(ENUM_ORDER_TYPE type, double price) {
      double margin = 0;
      
      if (OrderCalcMargin(type, settings.symbol, settings.lot, price, margin)) {
        return AccountInfoDouble(ACCOUNT_MARGIN_FREE) > margin;
      }

      return false;
    }

    double getTP(ENUM_ORDER_TYPE type) {
      int maxIndex = 0;
      if (type == ORDER_TYPE_BUY) {
        maxIndex = iHighest(settings.symbol, PERIOD_CURRENT, MODE_OPEN, settings.bars, 1);
        return iOpen(settings.symbol, PERIOD_CURRENT, maxIndex);

      } else {
        maxIndex = iLowest(settings.symbol, PERIOD_CURRENT, MODE_OPEN, settings.bars, 1);
        return iOpen(settings.symbol, PERIOD_CURRENT, maxIndex);
      }
    }

    double getSL(ENUM_ORDER_TYPE type) {
      int maxIndex = 0;
      if (type == ORDER_TYPE_BUY) {
        maxIndex = iLowest(settings.symbol, PERIOD_CURRENT, MODE_LOW, settings.bars, 1);
        return iLow(settings.symbol, PERIOD_CURRENT, maxIndex);

      } else {
        maxIndex = iHighest(settings.symbol, PERIOD_CURRENT, MODE_HIGH, settings.bars, 1);
        return iHigh(settings.symbol, PERIOD_CURRENT, maxIndex);
      }
    }

    /**
     * Оставляет только одну позицию с самой свежей датой создания
     * @param  tickets: тикеты открытых позиций
     * @return результат закрытия позиций
     */
    bool closeOldestPositions(ulong &tickets[]) {
      //Определение самой свежей по времени позиции
        ulong mostRecentTicket = 0;
        long mostRecentTime = 0;
        int posCount = ArraySize(tickets);
        
        for(int i = 0; i < posCount; i++) {
          PositionMonitor m(tickets[i]);
          long time = m.get(POSITION_TIME_MSC);
          if (time > mostRecentTime) {
            mostRecentTime = time;
            mostRecentTicket = tickets[i];
          }
        }
        
        //Закрытие самых старых позиций
        for (int i = 0; i < posCount; i++) {
          if (tickets[i] != mostRecentTicket) {
            if (!close(tickets[i])) {
              return false;
            }
          }
        }

        return true;
    }

    bool close(ulong ticket) {
      MqlTradeRequestSync request;
      prepare(request);
      return request.close(ticket) && postprocess(request);
    }

    void prepare(MqlTradeRequestSync &request) {
      request.deviation = fmin((int)(mSymbol.get(SYMBOL_SPREAD) + 1) * 2, settings.maxDiviation);
      request.magic = gMagic;
    }

    ulong postprocess(MqlTradeRequestSync &request)
    {
      if(request.result.order == 0)
      {
        badConditions = (datetime)(TimeCurrent() / settings.skipTimeOnError * settings.skipTimeOnError);
      }
      else
      {
        if(request.completed())
        {
          return request.result.position;
        }
      }
      return 0;
   }
};

//+------------------------------------------------------------------+
//| Global variable                                                  |
//+------------------------------------------------------------------+
AutoPtr<SeveralBars> strategy;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(60);
//---
   Settings s;
   s.defaults();
   s.lot = iLot;
   s.maxDiviation = iMaxDiviation;
   s.bars = iBars;
   s.skipTimeOnError = iSkipSecOnError;
   s.tickwise = iTickwise;
   s.tradeTime.enable = iEnable;
   s.tradeTime.startHour = iStartHour;
   s.tradeTime.endHour = iEndHour;

   if (s.validate()) {
      strategy = new SeveralBars(s);
      return INIT_SUCCEEDED;
   }
   
   return INIT_FAILED;
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   strategy[].trade();
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
//---
   double ret=0.0;
//---

//---
   return(ret);
  }
//+------------------------------------------------------------------+
//| TesterInit function                                              |
//+------------------------------------------------------------------+
void OnTesterInit()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| TesterPass function                                              |
//+------------------------------------------------------------------+
void OnTesterPass()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| TesterDeinit function                                            |
//+------------------------------------------------------------------+
void OnTesterDeinit()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| BookEvent function                                               |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
  {
//---
   
  }
//+------------------------------------------------------------------+
