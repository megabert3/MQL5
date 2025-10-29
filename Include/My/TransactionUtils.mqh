//+------------------------------------------------------------------+
//|                                             TransactionUtils.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

#include <My/Monitors/DealFilter.mqh>
#include <My/Monitors/PositionFilter.mqh>
#include <My/Monitors/OrderFilter.mqh>

//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+
namespace T {

    void printPostion(ulong ticket) {
        PositionMonitor pm(ticket);
        pm.list2log<ENUM_POSITION_PROPERTY_INTEGER>();
        pm.list2log<ENUM_POSITION_PROPERTY_DOUBLE>();
        pm.list2log<ENUM_POSITION_PROPERTY_STRING>();
    }

    void printOrder(ulong ticket) {
        OrderMonitor om(ticket);
        om.list2log<ENUM_ORDER_PROPERTY_INTEGER>();
        om.list2log<ENUM_ORDER_PROPERTY_DOUBLE>();
        om.list2log<ENUM_ORDER_PROPERTY_STRING>();
    }

    void printDeal(ulong ticket) {
        DealMonitor dm(ticket);
        dm.list2log<ENUM_DEAL_PROPERTY_INTEGER>();
        dm.list2log<ENUM_DEAL_PROPERTY_DOUBLE>();
        dm.list2log<ENUM_DEAL_PROPERTY_STRING>();
    }

    void getAllPositions(ulong &to[]) {
        TransactionFilter f;
        f.getPositions().collect(to);
    }

    void getAllOrders(ulong &to[]) {
        TransactionFilter f;
        f.getOrders().collect(to);
    }

    void getAllDeals(ulong &to[]) {
        TransactionFilter f;
        f.getDeals().collect(to);
    }

    /**
     * Обёртка над классами получения ордеров, позиций и сделок
     **/
    class TransactionFilter {
        private:
            enum TransactionType {
                POSITION,
                ORDER,
                DEAL
            };

            TransactionType type;
            PositionFilter pos;
            DealFilter deal;
            OrderFilter order;

        public:
            TransactionFilter *getPositions() {
                pos = PositionFilter();
                type = POSITION;
                return &this;
            }

            TransactionFilter *getOrders() {
                deal = DealFilter();
                type = ORDER;
                return &this;
            }

            TransactionFilter *getDeals() {
                order = OrderFilter();
                type = DEAL;
                return &this;
            }

            //Позиции
            TransactionFilter *filter(ENUM_POSITION_PROPERTY_INTEGER property, long value, IS cmp = EQUAL) {
                pos.let(property, value, cmp);
                return &this;
            }

            TransactionFilter *filter(ENUM_POSITION_PROPERTY_DOUBLE property, double value, IS cmp = EQUAL) {
                pos.let(property, value, cmp);
                return &this;
            }

            TransactionFilter *filter(ENUM_POSITION_PROPERTY_STRING property, string value, IS cmp = EQUAL) {
                pos.let(property, value, cmp);
                return &this;
            }

            //Ордеры
            TransactionFilter *filter(ENUM_ORDER_PROPERTY_INTEGER property, long value, IS cmp = EQUAL) {
                order.let(property, value, cmp);
                return &this;
            }

            TransactionFilter *filter(ENUM_ORDER_PROPERTY_DOUBLE property, double value, IS cmp = EQUAL) {
                order.let(property, value, cmp);
                return &this;
            }

            TransactionFilter *filter(ENUM_ORDER_PROPERTY_STRING property, string value, IS cmp = EQUAL) {
                order.let(property, value, cmp);
                return &this;
            }
            
            //Сделки
            TransactionFilter *filter(ENUM_DEAL_PROPERTY_INTEGER property, long value, IS cmp = EQUAL) {
                deal.let(property, value, cmp);
                return &this;
            }
            TransactionFilter *filter(ENUM_DEAL_PROPERTY_DOUBLE property, double value, IS cmp = EQUAL) {
                deal.let(property, value, cmp);
                return &this;
            }
            TransactionFilter *filter(ENUM_DEAL_PROPERTY_STRING property, string value, IS cmp = EQUAL) {
                deal.let(property, value, cmp);
                return &this;
            }
            
            //Возможно нужно будет переделать на динамический массив
            void collect(ulong &tickets[]) {
                switch (type) {
                    case ORDER: {
                        order.select(tickets);
                        break;
                    }
                    case POSITION: {
                        pos.select(tickets);
                        break;
                    }
                    case DEAL: {
                        deal.select(tickets);
                        break;
                    }
                    default: {
                        Print("Uncorrect TransactionType can't take tickets");
                    }
                }
            }
    };

};