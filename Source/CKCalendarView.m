//
// Copyright (c) 2012 Jason Kozemczak
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
// and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
// THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//


#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
#import "CKCalendarView.h"
#import "NSObject+VRCategory.h"
#import "DepDateDao.h"

#define BUTTON_MARGIN 4
#define CALENDAR_MARGIN 5
#define TOP_HEIGHT 44
#define DAYS_HEADER_HEIGHT 22
#define DEFAULT_CELL_WIDTH 43
#define CELL_BORDER_WIDTH 1

@class CALayer;
@class CAGradientLayer;

@interface GradientView : UIView

@property(nonatomic, strong, readonly) CAGradientLayer *gradientLayer;
- (void)setColors:(NSArray *)colors;

@end

@implementation GradientView

- (id)init {
    return [self initWithFrame:CGRectZero];
}

+ (Class)layerClass {
    return [CAGradientLayer class];
}

- (CAGradientLayer *)gradientLayer {
    return (CAGradientLayer *)self.layer;
}

- (void)setColors:(NSArray *)colors {
    NSMutableArray *cgColors = [NSMutableArray array];
    for (UIColor *color in colors) {
        [cgColors addObject:(__bridge id)color.CGColor];
    }
    self.gradientLayer.colors = cgColors;
}

@end


@interface DateButton : UIButton

@property (nonatomic, strong) NSDate *date;
@property (nonatomic, strong) CKDateItem *dateItem;
@property (nonatomic, strong) NSCalendar *calendar;

@end

@implementation DateButton

- (void)setDate:(NSDate *)date {
    _date = date;
    if (date) {
        NSDateComponents *comps = [self.calendar components:NSCalendarUnitDay|NSCalendarUnitMonth fromDate:date];
        [self setTitle:[NSString stringWithFormat:@"%ld", (long)comps.day] forState:UIControlStateNormal];
    } else {
        [self setTitle:@"" forState:UIControlStateNormal];
    }
}

@end

@implementation CKDateItem

- (id)init {
    self = [super init];
    if (self) {
        self.backgroundColor = SRArgb(0xffffffff);
        self.selectedBackgroundColor = SRArgb(0xff4183d7);
        self.textColor = SRArgb(0xff000000);
        self.selectedTextColor = SRArgb(0xffffffff);
    }
    return self;
}

@end

@interface CKCalendarView ()

@property(nonatomic, strong) UIView *highlight;
@property(nonatomic, strong) UILabel *titleLabel;
// hファイルに移動
//@property(nonatomic, strong) UIButton *prevButton;
//@property(nonatomic, strong) UIButton *nextButton;

//@property(nonatomic, strong) UIImageView *prevButtonImage;
//@property(nonatomic, strong) UIImageView *nextButtonImage;

@property(nonatomic, strong) UIView *calendarContainer;
@property(nonatomic, strong) GradientView *daysHeader;
@property(nonatomic, strong) UIView *daysHeaderLine;
@property(nonatomic, strong) NSArray *dayOfWeekLabels;
@property(nonatomic, strong) NSMutableArray *dateButtons;
@property(nonatomic, strong) NSMutableArray *dateButtonsUnderlines;
@property(nonatomic, strong) NSDateFormatter *dateFormatter;

@property (nonatomic, strong) NSDate *monthShowing;
@property (nonatomic, strong) NSDate *selectedDate;
@property (nonatomic, strong) NSCalendar *calendar;
@property(nonatomic, assign) CGFloat cellWidth;

@end

@implementation CKCalendarView

@dynamic locale;

- (id)init {
    return [self initWithStartDay:startSunday];
}

- (id)initWithStartDay:(CKCalendarStartDay)firstDay {
    return [self initWithStartDay:firstDay frame:CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_WIDTH)];
}

//- (void)_init:(CKCalendarStartDay)firstDay {
- (void)_init:(CKCalendarStartDay)firstDay inDate:(NSDate *)date {
    self.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    //[self.calendar setLocale:[NSLocale currentLocale]];
    [self.calendar setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"US"]];

    self.cellWidth = DEFAULT_CELL_WIDTH;

    self.dateFormatter = [[NSDateFormatter alloc] init];
    [self.dateFormatter setTimeStyle:kCFDateFormatterFullStyle];
    self.dateFormatter.dateFormat = [self isCurrentLanguageJapanese] ? @"yyyy年 LLLL" : @"LLLL yyyy";

    self.calendarStartDay = firstDay;
    self.onlyShowCurrentMonth = YES;
    self.adaptHeightToNumberOfWeeksInMonth = YES;

    // selfは一番外枠
    //self.layer.cornerRadius = 6.0f;

    /*
    UIView *highlight = [[UIView alloc] initWithFrame:CGRectZero];
    highlight.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
    highlight.layer.cornerRadius = 6.0f;
    [self addSubview:highlight];
    self.highlight = highlight;
     */

    // SET UP THE HEADER
    // カレンダータイトル
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth;
    [self addSubview:titleLabel];
    self.titleLabel = titleLabel;

    // 先月へボタン
    UIButton *prevButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [prevButton setImage:[UIImage imageNamed:@"btn_arr_01"] forState:UIControlStateNormal];
    prevButton.backgroundColor = [UIColor clearColor];
    prevButton.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
    [prevButton addTarget:self action:@selector(_moveCalendarToPreviousMonth) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:prevButton];
    self.prevButton = prevButton;

    // 次月へボタン
    UIButton *nextButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [nextButton setImage:[UIImage imageNamed:@"btn_arr_02"] forState:UIControlStateNormal];
    nextButton.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin;
    [nextButton addTarget:self action:@selector(_moveCalendarToNextMonth) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:nextButton];
    self.nextButton = nextButton;

    // THE CALENDAR ITSELF
    // カレンダーの外枠
    UIView *calendarContainer = [[UIView alloc] initWithFrame:CGRectZero];
    //calendarContainer.layer.borderWidth = 1.0f;
    //calendarContainer.layer.borderColor = [UIColor blackColor].CGColor;
    calendarContainer.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    //calendarContainer.layer.cornerRadius = 4.0f;
    //calendarContainer.clipsToBounds = YES;
    [self addSubview:calendarContainer];
    self.calendarContainer = calendarContainer;

    // 曜日のヘッダー部
    GradientView *daysHeader = [[GradientView alloc] initWithFrame:CGRectZero];
    daysHeader.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth;
    [self.calendarContainer addSubview:daysHeader];
    self.daysHeader = daysHeader;
    
    // 曜日のヘッダー部下ライン
    UIView *daysHeaderLine = [[UIView alloc] initWithFrame:CGRectZero];
    daysHeaderLine.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth;
    [self.calendarContainer addSubview:daysHeaderLine];
    self.daysHeaderLine = daysHeaderLine;

    // 曜日
    NSMutableArray *labels = [NSMutableArray array];
    for (int i = 0; i < 7; ++i) {
        UILabel *dayOfWeekLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        dayOfWeekLabel.textAlignment = NSTextAlignmentCenter;
        dayOfWeekLabel.backgroundColor = [UIColor clearColor];
        //dayOfWeekLabel.shadowColor = [UIColor whiteColor];
        //dayOfWeekLabel.shadowOffset = CGSizeMake(0, 1);
        [labels addObject:dayOfWeekLabel];
        [self.calendarContainer addSubview:dayOfWeekLabel];
    }
    self.dayOfWeekLabels = labels;
    [self _updateDayOfWeekLabels];

    // at most we'll need 42 buttons, so let's just bite the bullet and make them now...
    // 日付
    NSMutableArray *dateButtons = [NSMutableArray array];
    for (NSInteger i = 1; i <= 42; i++) {
        DateButton *dateButton = [DateButton buttonWithType:UIButtonTypeCustom];
        dateButton.calendar = self.calendar;
        [dateButton addTarget:self action:@selector(_dateButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [dateButtons addObject:dateButton];
    }
    self.dateButtons = dateButtons;
    
    // 各週毎の日付下ライン
    NSMutableArray *dateButtonsUnderlines = [NSMutableArray array];
    for (NSInteger i = 1; i <= 6; i++) {
        UIView *dateButtonsUnderline = [[UIView alloc] initWithFrame:CGRectZero];
        dateButtonsUnderline.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth;
        [dateButtonsUnderlines addObject:dateButtonsUnderline];
    }
    self.dateButtonsUnderlines = dateButtonsUnderlines;

    // initialize the thing
    //self.monthShowing = [NSDate date];
    self.monthShowing = date;
    if ([AppContext currentCriteria].strDepartDateYYYYMM.length > 0 && [AppContext currentCriteria].strDepartDateDD.length > 0) {
         // 年月日全てセットされている場合、日付を選択状態にする
        self.selectedDate = date;
    }
    [self _setDefaultStyle];
    
    [self layoutSubviews]; // TODO: this is a hack to get the first month to show properly
}

- (id)initWithStartDay:(CKCalendarStartDay)firstDay frame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self _init:firstDay inDate:[NSDate date]];
    }
    return self;
}

- (id)initWithStartDay:(CKCalendarStartDay)firstDay frame:(CGRect)frame date:(NSDate *)date {
    self = [super initWithFrame:frame];
    if (self) {
        [self _init:firstDay inDate:date];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    return [self initWithStartDay:startSunday frame:frame];
}

- (id)initWithCoder:(NSCoder *)aDecoder inDate:(NSDate *)date  {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self _init:startSunday inDate:date];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat containerWidth = self.bounds.size.width - (CALENDAR_MARGIN * 2);
    self.cellWidth = (floorf(containerWidth / 7.0));

    NSInteger numberOfWeeksToShow = 6;
    if (self.adaptHeightToNumberOfWeeksInMonth) {
        numberOfWeeksToShow = [self _numberOfWeeksInMonthContainingDate:self.monthShowing];
    }
    CGFloat containerHeight = (numberOfWeeksToShow * (self.cellWidth + CELL_BORDER_WIDTH) + DAYS_HEADER_HEIGHT);

    CGRect newFrame = self.frame;
    newFrame.size.height = containerHeight + CALENDAR_MARGIN + TOP_HEIGHT;
    self.frame = newFrame;

    //self.highlight.frame = CGRectMake(1, 1, self.bounds.size.width - 2, 1);

    self.titleLabel.text = [self.dateFormatter stringFromDate:_monthShowing];
    self.strTitle = self.titleLabel.text;
    self.titleLabel.frame = CGRectMake(0, 0, self.bounds.size.width, TOP_HEIGHT);
    self.prevButton.frame = CGRectMake(BUTTON_MARGIN, BUTTON_MARGIN, 48, 38);
    self.nextButton.frame = CGRectMake(self.bounds.size.width - 48 - BUTTON_MARGIN, BUTTON_MARGIN, 48, 38);

    self.calendarContainer.frame = CGRectMake(CALENDAR_MARGIN, CGRectGetMaxY(self.titleLabel.frame), containerWidth, containerHeight);
    self.daysHeader.frame = CGRectMake(0, 0, self.calendarContainer.frame.size.width, DAYS_HEADER_HEIGHT);
    self.daysHeaderLine.frame = CGRectMake(self.daysHeader.frame.origin.x, self.daysHeader.frame.size.height - 1, self.daysHeader.frame.size.width, 1);

    CGRect lastDayFrame = CGRectZero;
    int weekCnt = 0;
    for (UILabel *dayLabel in self.dayOfWeekLabels) {
         dayLabel.frame = CGRectMake(weekCnt * (self.cellWidth + CELL_BORDER_WIDTH) - 3, lastDayFrame.origin.y, self.cellWidth + CELL_BORDER_WIDTH, self.daysHeader.frame.size.height);
        lastDayFrame = dayLabel.frame;
        weekCnt++;
    }

    for (DateButton *dateButton in self.dateButtons) {
        dateButton.date = nil;
        [dateButton removeFromSuperview];
    }

    NSDate *date = [self _firstDayOfMonthContainingDate:self.monthShowing];
    if (!self.onlyShowCurrentMonth) {
        while ([self _placeInWeekForDate:date] != 0) {
            date = [self _previousDay:date];
        }
    }

    NSDate *endDate = [self _firstDayOfNextMonthContainingDate:self.monthShowing];
    if (!self.onlyShowCurrentMonth) {
        NSDateComponents *comps = [[NSDateComponents alloc] init];
        [comps setWeekOfMonth:numberOfWeeksToShow];
        endDate = [self.calendar dateByAddingComponents:comps toDate:date options:0];
    }

    NSUInteger dateButtonPosition = 0;
    while ([date laterDate:endDate] != date) {
        DateButton *dateButton = [self.dateButtons objectAtIndex:dateButtonPosition];
        

        dateButton.date = date;
        CKDateItem *item = [[CKDateItem alloc] init];
        if ([self _dateIsToday:dateButton.date]) {
            item.textColor = SRArgb(0xff000000);
            item.backgroundColor = SRArgb(0xffe5e5e5);
        } else if (!self.onlyShowCurrentMonth && [self _compareByMonth:date toDate:self.monthShowing] != NSOrderedSame) {
            item.textColor = SRArgb(0xffb2b2b2);
        }

        if (self.delegate && [self.delegate respondsToSelector:@selector(calendar:configureDateItem:forDate:)]) {
            [self.delegate calendar:self configureDateItem:item forDate:date];
        }

        if (self.selectedDate && [self date:self.selectedDate isSameDayAsDate:date]) {
            [dateButton setTitleColor:item.selectedTextColor forState:UIControlStateNormal];
            dateButton.backgroundColor = item.selectedBackgroundColor;
        } else {
            [dateButton setTitleColor:item.textColor forState:UIControlStateNormal];
            dateButton.backgroundColor = item.backgroundColor;
        }

        dateButton.frame = [self _calculateDayCellFrame:date];
        dateButton.layer.cornerRadius = 2.0f;
        // これが原因で表示が遅くなってしまったのでコメントアウト
        //dateButton.clipsToBounds = YES;

        [self.calendarContainer addSubview:dateButton];

        date = [self _nextDay:date];
        dateButtonPosition++;
    }
    
    // // 各週毎の日付下ライン
    int rowCnt = 1;
    for (UIView *dateUnderline in self.dateButtonsUnderlines) {
        dateUnderline.frame = CGRectMake(self.daysHeader.frame.origin.x,  (rowCnt * (self.cellWidth + CELL_BORDER_WIDTH)) + CGRectGetMaxY(self.daysHeader.frame) + CELL_BORDER_WIDTH - 1, self.daysHeader.frame.size.width, 1);
        dateUnderline.backgroundColor = SRArgb(0xffc8c7cc);
        [self.calendarContainer addSubview:dateUnderline];
        rowCnt++;
    }
    
    if ([self.delegate respondsToSelector:@selector(calendar:didLayoutInRect:)]) {
        [self.delegate calendar:self didLayoutInRect:self.frame];
    }
}

- (void)_updateDayOfWeekLabels {
    NSArray *weekdays = [self.dateFormatter shortWeekdaySymbols];
    // adjust array depending on which weekday should be first
    NSUInteger firstWeekdayIndex = [self.calendar firstWeekday] - 1;
    if (firstWeekdayIndex > 0) {
        weekdays = [[weekdays subarrayWithRange:NSMakeRange(firstWeekdayIndex, 7 - firstWeekdayIndex)]
                    arrayByAddingObjectsFromArray:[weekdays subarrayWithRange:NSMakeRange(0, firstWeekdayIndex)]];
    }

    NSUInteger i = 0;
    for (NSString *day in weekdays) {
        [[self.dayOfWeekLabels objectAtIndex:i] setText:[day uppercaseString]];
        i++;
    }
}

- (void)setCalendarStartDay:(CKCalendarStartDay)calendarStartDay {
    _calendarStartDay = calendarStartDay;
    [self.calendar setFirstWeekday:self.calendarStartDay];
    [self _updateDayOfWeekLabels];
    [self setNeedsLayout];
}

- (void)setLocale:(NSLocale *)locale {
    [self.dateFormatter setLocale:locale];
    [self _updateDayOfWeekLabels];
    [self setNeedsLayout];
}

- (NSLocale *)locale {
    return self.dateFormatter.locale;
}

- (NSArray *)datesShowing {
    NSMutableArray *dates = [NSMutableArray array];
    // NOTE: these should already be in chronological order
    for (DateButton *dateButton in self.dateButtons) {
        if (dateButton.date) {
            [dates addObject:dateButton.date];
        }
    }
    return dates;
}

- (void)setMonthShowing:(NSDate *)aMonthShowing {
    _monthShowing = [self _firstDayOfMonthContainingDate:aMonthShowing];
    [self setNeedsLayout];
}

- (void)setOnlyShowCurrentMonth:(BOOL)onlyShowCurrentMonth {
    _onlyShowCurrentMonth = onlyShowCurrentMonth;
    [self setNeedsLayout];
}

- (void)setAdaptHeightToNumberOfWeeksInMonth:(BOOL)adaptHeightToNumberOfWeeksInMonth {
    _adaptHeightToNumberOfWeeksInMonth = adaptHeightToNumberOfWeeksInMonth;
    [self setNeedsLayout];
}

- (void)selectDate:(NSDate *)date makeVisible:(BOOL)visible {
    NSMutableArray *datesToReload = [NSMutableArray array];
    if (self.selectedDate) {
        [datesToReload addObject:self.selectedDate];
    }
    if (date) {
        [datesToReload addObject:date];
    }
    self.selectedDate = date;
    [self reloadDates:datesToReload];
    if (visible && date) {
        self.monthShowing = date;
    }
}

- (void)reloadData {
    self.selectedDate = nil;
    [self setNeedsLayout];
}

- (void)reloadDates:(NSArray *)dates {
    // TODO: only update the dates specified
    [self setNeedsLayout];
}

- (void)_setDefaultStyle {
    self.backgroundColor = [UIColor clearColor];

    [self setTitleColor:SRArgb(0xff000000)];
    [self setTitleFont:DEFAULT_FONT(17.0f)];

    [self setDayOfWeekFont:DEFAULT_FONT(12.0f)];
    [self setDayOfWeekTextColor:SRArgb(0xff8e8e93)];
    //[self setDayOfWeekBottomColor:SRArgb(0xffCCCFD5) topColor:[UIColor whiteColor]];
    self.daysHeader.backgroundColor = SRArgb(0xffffffff);
    self.daysHeaderLine.backgroundColor = SRArgb(0xff666666);

    [self setDateFont:DEFAULT_FONT(14.0f)];
    [self setDateBorderColor:SRArgb(0xffffffff)];
    
}

- (CGRect)_calculateDayCellFrame:(NSDate *)date {
    NSInteger numberOfDaysSinceBeginningOfThisMonth = [self _numberOfDaysFromDate:self.monthShowing toDate:date];
    NSInteger row = (numberOfDaysSinceBeginningOfThisMonth + [self _placeInWeekForDate:self.monthShowing]) / 7;
	
    NSInteger placeInWeek = [self _placeInWeekForDate:date];

    return CGRectMake(placeInWeek * (self.cellWidth + CELL_BORDER_WIDTH), (row * (self.cellWidth + CELL_BORDER_WIDTH)) + CGRectGetMaxY(self.daysHeader.frame) + CELL_BORDER_WIDTH + 2, self.cellWidth - 4, self.cellWidth - 4);
}

- (void)_moveCalendarToNextMonth {
    NSDateComponents* comps = [[NSDateComponents alloc] init];
    [comps setMonth:1];
    NSDate *newMonth = [self.calendar dateByAddingComponents:comps toDate:self.monthShowing options:0];
    if ([self.delegate respondsToSelector:@selector(calendar:willChangeToMonth:)] && ![self.delegate calendar:self willChangeToMonth:newMonth]) {
        return;
    } else {
        self.monthShowing = newMonth;
        if ([self.delegate respondsToSelector:@selector(calendar:didChangeToMonth:)] ) {
            [self.delegate calendar:self didChangeToMonth:self.monthShowing];
        }
    }
}

- (void)_moveCalendarToPreviousMonth {
    NSDateComponents* comps = [[NSDateComponents alloc] init];
    [comps setMonth:-1];
    NSDate *newMonth = [self.calendar dateByAddingComponents:comps toDate:self.monthShowing options:0];
    if ([self.delegate respondsToSelector:@selector(calendar:willChangeToMonth:)] && ![self.delegate calendar:self willChangeToMonth:newMonth]) {
        return;
    } else {
        self.monthShowing = newMonth;
        if ([self.delegate respondsToSelector:@selector(calendar:didChangeToMonth:)] ) {
            [self.delegate calendar:self didChangeToMonth:self.monthShowing];
        }
    }
}

- (void)_dateButtonPressed:(id)sender {
    DateButton *dateButton = sender;
    NSDate *date = dateButton.date;
    if ([date isEqualToDate:self.selectedDate]) {
        // deselection..
        if ([self.delegate respondsToSelector:@selector(calendar:willDeselectDate:)] && ![self.delegate calendar:self willDeselectDate:date]) {
            return;
        }
        // ここコメントアウトしないと選択中の日付を再度押した時に色が元の色に変わってしまう
        //date = nil;
    } else if ([self.delegate respondsToSelector:@selector(calendar:willSelectDate:)] && ![self.delegate calendar:self willSelectDate:date]) {
        return;
    }

    // 過去日チェック
    if (![self isTodayOrFutureDate:date]) {
        [self alertError:NSLocalizedString(@"CalendarViewController.pastDateErrorMessage", nil)];
        return;
    }
    // 年月日を取り出し、dateStringを作成
    NSUInteger flags = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
    // NSGregorianと指定しないといけない。[NSCalendar currentCalendar]だと、２０１２年ではなく２４年となった。
    // 自動的に日本のカレンダーになって平成２４年の２４を返したのだろう。
    NSCalendar *cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *comps = [cal components:flags fromDate:date];
    NSString *dateYMString = [NSString stringWithFormat:@"%ld%02ld", (long)[comps year], (long)[comps month]];
    // 未来日チェック
    if (![DepDateDao depDateByYMParamValue:dateYMString]) {
        [self alertError:NSLocalizedString(@"CalendarViewController.futureDateErrorMessage", nil)];
        return;
    }

    [self selectDate:date makeVisible:YES];
    [self.delegate calendar:self didSelectDate:date];
    [self setNeedsLayout];
}

#pragma mark - Theming getters/setters

- (void)setTitleFont:(UIFont *)font {
    self.titleLabel.font = font;
}
- (UIFont *)titleFont {
    return self.titleLabel.font;
}

- (void)setTitleColor:(UIColor *)color {
    self.titleLabel.textColor = color;
}
- (UIColor *)titleColor {
    return self.titleLabel.textColor;
}

- (void)setMonthButtonColor:(UIColor *)color {
    [self.prevButton setImage:[CKCalendarView _imageNamed:@"btn_arr_01" withColor:color] forState:UIControlStateNormal];
    [self.nextButton setImage:[CKCalendarView _imageNamed:@"btn_arr_02" withColor:color] forState:UIControlStateNormal];
}

- (void)setInnerBorderColor:(UIColor *)color {
    self.calendarContainer.layer.borderColor = color.CGColor;
}

- (void)setDayOfWeekFont:(UIFont *)font {
    for (UILabel *label in self.dayOfWeekLabels) {
        label.font = font;
    }
}
- (UIFont *)dayOfWeekFont {
    return (self.dayOfWeekLabels.count > 0) ? ((UILabel *)[self.dayOfWeekLabels lastObject]).font : nil;
}

- (void)setDayOfWeekTextColor:(UIColor *)color {
    for (UILabel *label in self.dayOfWeekLabels) {
        label.textColor = color;
    }
}
- (UIColor *)dayOfWeekTextColor {
    return (self.dayOfWeekLabels.count > 0) ? ((UILabel *)[self.dayOfWeekLabels lastObject]).textColor : nil;
}

- (void)setDayOfWeekBottomColor:(UIColor *)bottomColor topColor:(UIColor *)topColor {
    [self.daysHeader setColors:[NSArray arrayWithObjects:topColor, bottomColor, nil]];
}

- (void)setDateFont:(UIFont *)font {
    for (DateButton *dateButton in self.dateButtons) {
        dateButton.titleLabel.font = font;
    }
}
- (UIFont *)dateFont {
    return (self.dateButtons.count > 0) ? ((DateButton *)[self.dateButtons lastObject]).titleLabel.font : nil;
}

- (void)setDateBorderColor:(UIColor *)color {
    self.calendarContainer.backgroundColor = color;
}
- (UIColor *)dateBorderColor {
    return [UIColor redColor];
}

#pragma mark - Calendar helpers

- (NSDate *)_firstDayOfMonthContainingDate:(NSDate *)date {
    NSDateComponents *comps = [self.calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:date];
    comps.day = 1;
    return [self.calendar dateFromComponents:comps];
}

- (NSDate *)_firstDayOfNextMonthContainingDate:(NSDate *)date {
    NSDateComponents *comps = [self.calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:date];
    comps.day = 1;
    comps.month = comps.month + 1;
    return [self.calendar dateFromComponents:comps];
}

- (BOOL)dateIsInCurrentMonth:(NSDate *)date {
    return ([self _compareByMonth:date toDate:self.monthShowing] == NSOrderedSame);
}

- (NSComparisonResult)_compareByMonth:(NSDate *)date toDate:(NSDate *)otherDate {
    NSDateComponents *day = [self.calendar components:NSCalendarUnitYear|NSCalendarUnitMonth fromDate:date];
    NSDateComponents *day2 = [self.calendar components:NSCalendarUnitYear|NSCalendarUnitMonth fromDate:otherDate];

    if (day.year < day2.year) {
        return NSOrderedAscending;
    } else if (day.year > day2.year) {
        return NSOrderedDescending;
    } else if (day.month < day2.month) {
        return NSOrderedAscending;
    } else if (day.month > day2.month) {
        return NSOrderedDescending;
    } else {
        return NSOrderedSame;
    }
}

- (NSInteger)_placeInWeekForDate:(NSDate *)date {
    NSDateComponents *compsFirstDayInMonth = [self.calendar components:NSCalendarUnitWeekday fromDate:date];
    return (compsFirstDayInMonth.weekday - 1 - self.calendar.firstWeekday + 8) % 7;
}

- (BOOL)_dateIsToday:(NSDate *)date {
    return [self date:[NSDate date] isSameDayAsDate:date];
}

- (BOOL)date:(NSDate *)date1 isSameDayAsDate:(NSDate *)date2 {
    // Both dates must be defined, or they're not the same
    if (date1 == nil || date2 == nil) {
        return NO;
    }

    NSDateComponents *day = [self.calendar components:NSCalendarUnitEra|NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:date1];
    NSDateComponents *day2 = [self.calendar components:NSCalendarUnitEra|NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:date2];
    return ([day2 day] == [day day] &&
            [day2 month] == [day month] &&
            [day2 year] == [day year] &&
            [day2 era] == [day era]);
}

- (NSInteger)_numberOfWeeksInMonthContainingDate:(NSDate *)date {
    return [self.calendar rangeOfUnit:NSCalendarUnitWeekday inUnit:NSCalendarUnitMonth forDate:date].length;
}

- (NSDate *)_nextDay:(NSDate *)date {
    NSDateComponents *comps = [[NSDateComponents alloc] init];
    [comps setDay:1];
    return [self.calendar dateByAddingComponents:comps toDate:date options:0];
}

- (NSDate *)_previousDay:(NSDate *)date {
    NSDateComponents *comps = [[NSDateComponents alloc] init];
    [comps setDay:-1];
    return [self.calendar dateByAddingComponents:comps toDate:date options:0];
}

- (NSInteger)_numberOfDaysFromDate:(NSDate *)startDate toDate:(NSDate *)endDate {
    NSInteger startDay = [self.calendar ordinalityOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitEra forDate:startDate];
    NSInteger endDay = [self.calendar ordinalityOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitEra forDate:endDate];
    return endDay - startDay;
}

+ (UIImage *)_imageNamed:(NSString *)name withColor:(UIColor *)color {
    UIImage *img = [UIImage imageNamed:name];

    UIGraphicsBeginImageContextWithOptions(img.size, NO, [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [color setFill];

    CGContextTranslateCTM(context, 0, img.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);

    CGContextSetBlendMode(context, kCGBlendModeColorBurn);
    CGRect rect = CGRectMake(0, 0, img.size.width, img.size.height);
    CGContextDrawImage(context, rect, img.CGImage);

    CGContextClipToMask(context, rect, img.CGImage);
    CGContextAddRect(context, rect);
    CGContextDrawPath(context,kCGPathFill);

    UIImage *coloredImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return coloredImg;
}

@end