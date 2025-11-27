import React from 'react';
import { AlertCircle, AlertTriangle } from 'lucide-react';
import { NosebleedRecord } from '../App';

// Import severity icons from Figma assets
import spottingIcon from 'figma:asset/2abb485475a2155888f0b9cf5d60b00d0e60c0dc.png';
import drippingIcon from 'figma:asset/b7c32eb7099d240e6e35c5e4d31747c2f17d3f14.png';
import drippingQuicklyIcon from 'figma:asset/7143b924359de55136b437848338c8123becffb7.png';
import steadyStreamIcon from 'figma:asset/af3ed36b994236e727da82af8cc77fecd4419201.png';
import pouringIcon from 'figma:asset/d8f6cd656bd09578a87697e17d921cc06a8fe405.png';
import gushingIcon from 'figma:asset/2b7e1aa050a7930996e53d943b2b2436daf6a8ca.png';

interface EventListItemProps {
  record: NosebleedRecord & { originalIndex?: number };
  isIncomplete?: boolean;
  hasOverlap?: boolean;
  onClick?: () => void;
  clickable?: boolean;
}

const severityIcons: Record<string, { icon: React.ReactNode; color: string }> = {
  'Spotting': { icon: <img src={spottingIcon} alt="Spotting" className="w-4 h-4" />, color: 'text-green-600' },
  'Dripping': { icon: <img src={drippingIcon} alt="Dripping" className="w-4 h-4" />, color: 'text-yellow-600' },
  'Dripping quickly': { icon: <img src={drippingQuicklyIcon} alt="Dripping quickly" className="w-4 h-4" />, color: 'text-orange-600' },
  'Steady stream': { icon: <img src={steadyStreamIcon} alt="Steady stream" className="w-4 h-4" />, color: 'text-red-600' },
  'Pouring': { icon: <img src={pouringIcon} alt="Pouring" className="w-4 h-4" />, color: 'text-red-700' },
  'Gushing': { icon: <img src={gushingIcon} alt="Gushing" className="w-4 h-4" />, color: 'text-red-800' },
};

function formatTime(date: Date): string {
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

function formatDuration(startTime: Date, endTime: Date): string {
  const durationMs = endTime.getTime() - startTime.getTime();
  const minutes = Math.floor(durationMs / 60000);
  
  if (minutes < 60) {
    return `${minutes}m`;
  } else {
    const hours = Math.floor(minutes / 60);
    const remainingMinutes = minutes % 60;
    return remainingMinutes > 0 ? `${hours}h ${remainingMinutes}m` : `${hours}h`;
  }
}

export function EventListItem({ 
  record, 
  isIncomplete = false, 
  hasOverlap = false, 
  onClick, 
  clickable = true 
}: EventListItemProps) {
  const severityInfo = record.severity ? severityIcons[record.severity] : null;
  const duration = record.startTime && record.endTime ? formatDuration(record.startTime, record.endTime) : 'ongoing';

  // Handle special event types first
  if (record.isNoNosebleedsEvent) {
    return (
      <div className="w-full p-4 md:p-3 rounded-xl bg-green-50 dark:bg-green-900/10 border border-green-200 dark:border-green-800">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 md:w-8 md:h-8 bg-green-100 dark:bg-green-900/20 rounded-full flex items-center justify-center">
            <span className="text-green-600 dark:text-green-400 text-lg md:text-base">✓</span>
          </div>
          <div className="flex-1">
            <span className="text-green-800 dark:text-green-200 font-medium">
              No nosebleed events
            </span>
            <p className="text-green-600 dark:text-green-400 text-sm md:text-xs">
              Confirmed no events for this day
            </p>
          </div>
        </div>
      </div>
    );
  }

  if (record.isUnknownEvent) {
    return (
      <div className="w-full p-4 md:p-3 rounded-xl bg-yellow-50 dark:bg-yellow-900/10 border border-yellow-200 dark:border-yellow-800">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 md:w-8 md:h-8 bg-yellow-100 dark:bg-yellow-900/20 rounded-full flex items-center justify-center">
            <span className="text-yellow-600 dark:text-yellow-400 text-lg md:text-base">?</span>
          </div>
          <div className="flex-1">
            <span className="text-yellow-800 dark:text-yellow-200 font-medium">
              Unknown
            </span>
            <p className="text-yellow-600 dark:text-yellow-400 text-sm md:text-xs">
              Unable to recall events for this day
            </p>
          </div>
        </div>
      </div>
    );
  }

  if (record.isSurveyEvent) {
    return (
      <div 
        className="w-full p-4 md:p-3 rounded-xl bg-blue-50 dark:bg-blue-900/10 border border-blue-200 dark:border-blue-800 cursor-pointer hover:bg-blue-100 dark:hover:bg-blue-900/20 transition-colors"
        onClick={() => onClick && onClick()}
      >
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 md:w-8 md:h-8 bg-blue-100 dark:bg-blue-900/20 rounded-full flex items-center justify-center">
            <span className="text-blue-600 dark:text-blue-400 text-lg md:text-base">📋</span>
          </div>
          <div className="flex-1">
            <span className="text-blue-800 dark:text-blue-200 font-medium">
              {record.surveyName || 'Survey Completed'}
            </span>
            <p className="text-blue-600 dark:text-blue-400 text-sm md:text-xs">
              Completed at {record.startTime ? formatTime(record.startTime) : '--:--'}
            </p>
          </div>
          <div className="text-blue-600 dark:text-blue-400 text-sm md:text-xs">
            View Only
          </div>
        </div>
      </div>
    );
  }

  // For survey events in the compact HomeScreen format
  if (record.isSurveyEvent && !clickable) {
    return (
      <div className="w-full flex items-center gap-3 py-2 md:py-1.5 px-3 md:px-2.5 rounded-lg">
        <span className="text-foreground md:text-sm">
          {record.startTime ? formatTime(record.startTime) : '--:--'}
        </span>
        <span className="flex-1 text-foreground md:text-sm">
          {record.surveyName || 'Survey Completed'}
        </span>
        <span className="text-blue-600 dark:text-blue-400 text-sm md:text-xs">
          complete
        </span>
      </div>
    );
  }

  // Regular nosebleed events
  const Component = clickable ? 'button' : 'div';
  const baseClasses = `w-full flex items-center gap-3 py-2 md:py-1.5 px-3 md:px-2.5 rounded-lg text-left ${
    isIncomplete ? 'bg-orange-50 dark:bg-orange-900/10 border border-orange-200 dark:border-orange-800' : ''
  }`;
  const interactiveClasses = clickable ? 'hover:bg-muted/50 transition-colors' : '';

  return (
    <Component
      onClick={clickable ? onClick : undefined}
      className={`${baseClasses} ${interactiveClasses}`}
    >
      <span className="text-foreground md:text-sm">
        {record.startTime ? formatTime(record.startTime) : '--:--'}
      </span>
      <div className="flex-shrink-0">
        {severityInfo?.icon ? (
          <div className="w-4 h-4 md:w-3.5 md:h-3.5">
            {React.cloneElement(severityInfo.icon as React.ReactElement, {
              className: "w-full h-full"
            })}
          </div>
        ) : (
          <img src={spottingIcon} alt="Unknown severity" className="w-4 h-4 md:w-3.5 md:h-3.5 opacity-50" />
        )}
      </div>
      <span className="text-muted-foreground md:text-sm">
        {duration}
      </span>
      <div className="flex items-center gap-2 ml-auto">
        {isIncomplete && (
          <div className="flex items-center gap-1 text-orange-600 text-sm md:text-xs">
            <AlertCircle className="w-4 h-4 md:w-3.5 md:h-3.5 flex-shrink-0" />
            <span className="hidden sm:inline">Incomplete</span>
          </div>
        )}
        {hasOverlap && (
          <div className="flex-shrink-0 text-amber-600">
            <AlertTriangle className="w-4 h-4 md:w-3.5 md:h-3.5" />
          </div>
        )}
      </div>
    </Component>
  );
}