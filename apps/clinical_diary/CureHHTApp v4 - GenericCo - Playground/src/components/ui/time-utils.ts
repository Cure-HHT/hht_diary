/**
 * Utility functions for time formatting and calculations
 */

/**
 * Formats a time with an optional day difference indicator
 * @param time - The time to format
 * @param startTime - The start time to compare against (optional)
 * @param options - Formatting options for toLocaleTimeString
 * @returns Formatted time string with day difference if applicable
 */
export function formatTimeWithDayDifference(
  time: Date,
  startTime?: Date,
  options: Intl.DateTimeFormatOptions = { hour: 'numeric', minute: '2-digit', hour12: true }
): string {
  const formattedTime = time.toLocaleTimeString([], options);
  
  if (!startTime) {
    return formattedTime;
  }
  
  const dayDifference = getDayDifference(startTime, time);
  
  if (dayDifference === 0) {
    return formattedTime;
  }
  
  const dayText = dayDifference === 1 ? '+1 day' : `+${dayDifference} days`;
  return `${formattedTime} (${dayText})`;
}

/**
 * Calculates the number of days between two dates
 * @param startDate - The start date
 * @param endDate - The end date
 * @returns Number of days difference (positive if endDate is after startDate)
 */
export function getDayDifference(startDate: Date, endDate: Date): number {
  if (!startDate || !endDate || !(startDate instanceof Date) || !(endDate instanceof Date)) {
    return 0;
  }
  
  // Normalize dates to midnight for accurate day calculation
  const startDateOnly = new Date(startDate);
  startDateOnly.setHours(0, 0, 0, 0);
  
  const endDateOnly = new Date(endDate);
  endDateOnly.setHours(0, 0, 0, 0);
  
  const timeDifference = endDateOnly.getTime() - startDateOnly.getTime();
  return Math.round(timeDifference / (1000 * 60 * 60 * 24));
}

/**
 * Checks if two dates are on the same day
 * @param date1 - First date
 * @param date2 - Second date
 * @returns True if dates are on the same day
 */
export function isSameDay(date1: Date, date2: Date): boolean {
  if (!date1 || !date2 || !(date1 instanceof Date) || !(date2 instanceof Date)) {
    return false;
  }
  
  return date1.toDateString() === date2.toDateString();
}