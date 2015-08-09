import Foundation

public class MedicineStats : CoreDataContextManager{
    private let medicine: Medicine
    private let registriesManager: RegistriesManager
    
    public init(context: NSManagedObjectContext, medicine: Medicine) {
        self.medicine = medicine
        registriesManager = self.medicine.registriesManager(context)
        super.init(context: context)
    }
    
    /// Returns the number of pills taken between two dates
    ///
    /// :param: `NSDate optional`: first date (by default is NSDate.min)
    /// :param: `NSDate optional`: second date (by default is NSDate.max)
    /// :param: `[Registry] optional`: cached list of entries
    /// :returns: `Int`: Number of pills
    public func numberPillsTaken(date1: NSDate = NSDate.min, date2: NSDate = NSDate.max, registries: [Registry]? = nil) -> Int {
        if let reg = registries{
            return reg.filter({$0.tookMedicine}).count
        }

        return registriesManager.getRegistries(date1: date1, date2: date2, unsorted: true, additionalFilter: {(r: Registry) in return r.tookMedicine }).count
    }
    
    /// Returns the number of pills that the user should have taken between two dates.
    ///
    /// :param: `NSDate optional`: first date (by default is NSDate.min)
    /// :param: `NSDate optional`: second date (by default is NSDate.max)
    /// :param: `[Registry] optional`: cached list of entries
    /// :returns: `Int`: Number of supposed pills
    public func numberSupposedPills(date1: NSDate = NSDate.min, date2: NSDate = NSDate.max, registries: [Registry]? = nil) -> Int{
        if date1 > date2 {
            return numberSupposedPills(date1: date2, date2: date1, registries: registries)
        }
        
        var d1 = date1
        var d2 = date2
        if date1 == NSDate.min || date2 == NSDate.max {
            if let boundaries = registriesManager.getLimits() {
                (d1, d2) = (boundaries.leastRecent.date, boundaries.mostRecent.date)
            }else {
                return 0
            }
        }
        
        return MedicineStats.numberNeededPills(d1, date2: d2, interval: medicine.interval)
    }
    
    /// Returns the number of pills that the user should have taken between two dates.
    ///
    /// :param: `NSDate`: first date
    /// :param: `NSDate`: second date
    /// :param: `interval`: Interval (1 = once per day, 7 = once per week)
    /// :returns: `Int`: Number of supposed pills
    public class func  numberNeededPills(date1: NSDate, date2: NSDate, interval: Int) -> Int{
        if date1 > date2 {
            return numberNeededPills(date2, date2: date1, interval: interval)
        }
        let numDays = (date2 - date1) + 1
        return  Int(ceil(Float(numDays)/Float(interval)))
    }
    
    /// Returns the number of pills that the user should have taken between two dates
    ///
    //// Adherence = numberPillsTaken/SupposedPills
    ///
    /// :param: `NSDate optional`: first date (by default is NSDate.min)
    /// :param: `NSDate optional`: second date (by default is NSDate.max)
    /// :param: `[Registry] optional`: cached list of entries
    /// :returns: `Float`: Pill adherence
    public func pillAdherence(date1: NSDate = NSDate.min, date2: NSDate = NSDate.max, registries: [Registry]? = nil) -> Float{        
        let supposedPills = numberSupposedPills(date1: date1, date2: date2, registries: registries)
        
        if(supposedPills == 0){
            return 1.0
        }
        
        let pillsTaken = numberPillsTaken(date1: date1, date2: date2, registries: registries)
        
        return Float(pillsTaken)/(Float(supposedPills))
    }
    
    /// Returns the current Pill Streak of the user.
    ///
    /// If the user misses a day, the streak will be reset to 0
    ///
    /// :param: `NSDate optional`: first date (by default is NSDate.min)
    /// :param: `NSDate optional`: second date (by default is NSDate.max)
    /// :param: `[Registry]? optional`: Cached list of entries. Must be sorted from most recent to least recent
    /// :returns: `Int`: Pill streak
    public func pillStreak(date1: NSDate = NSDate.min, date2: NSDate = NSDate.max, registries: [Registry]? = nil) -> Int{
        let entries = registries != nil ? registries! : registriesManager.getRegistries(date1: date1, date2: date2, mostRecentFirst: true)
        
        var result = 0
        
        var previousDate: NSDate?
        for r in entries {
            //check for missing entries
            if let previousD = previousDate {
                if r.date < previousD - medicine.interval.day {
                    return result
                }
            }
            
            if r.tookMedicine{
                result += 1
            }else{
                return result
            }
            
            previousDate = r.date
        }
        
        return result
    }
    
    /// Returns pill adhrence in a month
    /// If there are no entries in that month return 0
    /// Starts at max(oldest entry ; first day of the month)
    /// If current month, only goes up to today
    /// If not, goes up to the mostRecentEntry
    ///
    /// :param: `NSDate`: The month
    /// :param: `Registries`: Previously calculated entries. Must be sorted oldest to recent
    /// :returns: `Float`: pill adherence for the month
    public func pillAdherence(month: NSDate, registries: [Registry]? = nil) -> Float{
        let entries = registries != nil ? registries! : registriesManager.getRegistries(mostRecentFirst: false)
        
        if entries.count == 0 {
            return 1
        }
        
        let (oldestDate, mostRecentEntry) = (entries.first!.date, entries.last!.date)
        
        let (startMonth, endMonth) = (NSDate.from(month.year, month: month.month, day: 1), NSDate.from(month.year, month: month.month, day: month.endOfCurrentMonth))
        
        if startMonth.happensMonthsBefore(oldestDate) {
            return 1.0
        }
        
        let day1 = max(startMonth, oldestDate)
        let day2 = endMonth.sameMonthAs(NSDate()) ? min(endMonth, NSDate()) : endMonth
        
        return pillAdherence(date1: day1, date2: day2, registries: registriesManager.filter(entries, date1: day1, date2: day2))
    }
    
}