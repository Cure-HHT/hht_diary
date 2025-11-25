import React, { useState } from 'react';
import { Button } from './ui/button';
import { Plus, User, AlertCircle, RotateCcw, AlertTriangle, MoreVertical, Database, Trash2, FileText, ClipboardCheck, Users, Calendar } from 'lucide-react';
import { Switch } from './ui/switch';
import { Popover, PopoverContent, PopoverTrigger } from './ui/popover';
import { EventListItem } from './EventListItem';

import { NosebleedRecord } from '../App';
import terremotoLogo from 'figma:asset/9997d4b256716c0b02083326d928c9827bd6cd4f.png';
import cureHHTLogo from 'figma:asset/ba09a9637ac0ff172dab598ce95c889db4cb245f.png';

interface HomeScreenProps {
  onStartRecording: () => void;
  onUpdateProfile: () => void;
  onEditRecord: (index: number) => void;
  onShowCalendar: () => void;
  onConfirmNoNosebleedsYesterday: () => void;
  onConfirmYesterdayHadNosebleeds: () => void;
  onConfirmYesterdayDontRemember: () => void;
  onShowMissingDataCalendar: () => void;
  onStartNoseStudyQuestionnaire: () => void;
  onStartQualityOfLifeSurvey: () => void;
  onShowActiveQuestionnaire: () => void;
  showNoNosebleedsButton: boolean;
  showMissingDataButton: boolean;
  showQuestionnaireButton: boolean;
  activeQuestionnaireName?: string;
  incompleteRecords: NosebleedRecord[];
  recordsWithOverlaps: Set<string>;
  demoMode: boolean;
  onToggleDemoMode: () => void;
  onResetAllData: () => void;
  onAddExampleData: () => void;
  records: NosebleedRecord[];
  logoSrc?: string;
  logoAlt?: string;
  isSharingWithCureHHT?: boolean;
  isEnrolledInTrial?: boolean;
  enrollmentStatus?: 'active' | 'ended';
  onEndClinicalTrialEnrollment?: () => void;
  onShowAccessibilityPreferences?: () => void;
  onShowPrivacyDataProtection?: () => void;
  onShowEnrollInTrial?: () => void;
}



function getRecentRecords(records: NosebleedRecord[], incompleteRecords: NosebleedRecord[]) {
  const now = new Date();
  const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
  
  return records
    .map((record, originalIndex) => ({ ...record, originalIndex }))
    .filter(record => {
      // Ensure record has valid startTime
      if (!record.startTime || !(record.startTime instanceof Date)) {
        return false;
      }
      
      // Always include incomplete records regardless of age
      const isIncomplete = incompleteRecords.some(ir => ir.id === record.id);
      const isRecent = record.startTime >= twentyFourHoursAgo;
      const isRealEvent = !record.isNoNosebleedsEvent && !record.isUnknownEvent;
      
      return isRealEvent && (isRecent || isIncomplete);
    })
    .sort((a, b) => {
      // Safety check for startTime before calling getTime()
      if (!a.startTime || !b.startTime) {
        return 0;
      }
      return a.startTime.getTime() - b.startTime.getTime();
    });
}

function groupRecordsByDay(records: Array<NosebleedRecord & { originalIndex: number }>, incompleteRecords: NosebleedRecord[], allRecords: NosebleedRecord[]) {
  const today = new Date();
  const todayStr = today.toDateString();
  const yesterday = new Date(today.getTime() - 24 * 60 * 60 * 1000);
  const yesterdayStr = yesterday.toDateString();
  
  const groups: { label: string; records: Array<NosebleedRecord & { originalIndex: number }>; isEmpty?: boolean }[] = [];
  
  // Separate incomplete records that are older than yesterday
  const olderIncompleteRecords = records.filter(record => {
    if (!record.startTime || !(record.startTime instanceof Date)) {
      return false;
    }
    const isIncomplete = incompleteRecords.some(ir => ir.id === record.id);
    const isOlderThanYesterday = record.startTime.toDateString() !== todayStr && record.startTime.toDateString() !== yesterdayStr;
    return isIncomplete && isOlderThanYesterday;
  });
  
  const yesterdayRecords = records.filter(record => {
    if (!record.startTime || !(record.startTime instanceof Date)) {
      return false;
    }
    return record.startTime.toDateString() === yesterdayStr;
  });
  
  const todayRecords = records.filter(record => {
    if (!record.startTime || !(record.startTime instanceof Date)) {
      return false;
    }
    return record.startTime.toDateString() === todayStr;
  });

  // Check if there are any records (including special events) for today and yesterday
  const hasAnyTodayRecords = allRecords.some(record => {
    if (!record.date || !(record.date instanceof Date)) return false;
    return record.date.toDateString() === todayStr;
  });

  const hasAnyYesterdayRecords = allRecords.some(record => {
    if (!record.date || !(record.date instanceof Date)) return false;
    return record.date.toDateString() === yesterdayStr;
  });
  
  // Add incomplete records section first if there are any older incomplete records
  if (olderIncompleteRecords.length > 0) {
    groups.push({ label: 'incomplete records', records: olderIncompleteRecords });
  }
  
  // Always show yesterday group
  if (yesterdayRecords.length > 0) {
    groups.push({ label: 'yesterday', records: yesterdayRecords });
  } else if (!hasAnyYesterdayRecords) {
    groups.push({ label: 'yesterday', records: [], isEmpty: true });
  }
  
  // Always show today group
  if (todayRecords.length > 0) {
    groups.push({ label: 'today', records: todayRecords });
  } else if (!hasAnyTodayRecords) {
    groups.push({ label: 'today', records: [], isEmpty: true });
  }
  
  return groups;
}

export function HomeScreen({ onStartRecording, onUpdateProfile, onEditRecord, onShowCalendar, onConfirmNoNosebleedsYesterday, onConfirmYesterdayHadNosebleeds, onConfirmYesterdayDontRemember, onShowMissingDataCalendar, onStartNoseStudyQuestionnaire, onStartQualityOfLifeSurvey, onShowActiveQuestionnaire, showNoNosebleedsButton, showMissingDataButton, showQuestionnaireButton, activeQuestionnaireName, incompleteRecords, recordsWithOverlaps, demoMode, onToggleDemoMode, onResetAllData, onAddExampleData, records, logoSrc = cureHHTLogo, logoAlt = "CureHHT", isSharingWithCureHHT = false, isEnrolledInTrial = false, enrollmentStatus = 'active', onEndClinicalTrialEnrollment, onShowAccessibilityPreferences, onShowPrivacyDataProtection, onShowEnrollInTrial }: HomeScreenProps) {
  const [logoMenuOpen, setLogoMenuOpen] = useState(false);
  const [userMenuOpen, setUserMenuOpen] = useState(false);
  
  const recentRecords = getRecentRecords(records, incompleteRecords);
  const groupedRecords = groupRecordsByDay(recentRecords, incompleteRecords, records);

  // Determine logo size classes based on which logo is being used
  const logoSizeClasses = logoSrc === terremotoLogo 
    ? "h-4 sm:h-5 lg:h-7" // Smaller size for Terremoto logo
    : "h-6 sm:h-8 lg:h-10"; // Original size for CureHHT logo

  // Handle clicking on incomplete records warning
  const handleIncompleteRecordsClick = () => {
    if (incompleteRecords.length === 0) return;
    
    // Find the first incomplete record in the recent records
    const firstIncompleteInRecent = recentRecords.find(record => 
      incompleteRecords.some(ir => ir.id === record.id)
    );
    
    if (firstIncompleteInRecent) {
      onEditRecord(firstIncompleteInRecent.originalIndex);
    } else {
      // If no incomplete records in recent view, edit the first incomplete record overall
      const firstIncompleteIndex = records.findIndex(record => 
        incompleteRecords.some(ir => ir.id === record.id)
      );
      if (firstIncompleteIndex !== -1) {
        onEditRecord(firstIncompleteIndex);
      }
    }
  };

  return (
    <div className="min-h-screen flex flex-col bg-background">
      {/* Header */}
      <div className="flex-none p-6 md:p-4">
        {/* Header Row with Interactive Logo and Title */}
        <div className="flex items-center justify-between mb-4 md:mb-3">
          <Popover open={logoMenuOpen} onOpenChange={setLogoMenuOpen}>
            <PopoverTrigger asChild>
              <button 
                className="focus:outline-none focus:ring-2 focus:ring-ring rounded-md p-1"
                aria-label="App settings menu"
              >
                <img 
                  src={logoSrc} 
                  alt={logoAlt} 
                  className={`${logoSizeClasses} opacity-75 hover:opacity-100 transition-opacity ${
                    logoSrc === cureHHTLogo && !isSharingWithCureHHT ? 'grayscale brightness-75' : ''
                  }`}
                />
              </button>
            </PopoverTrigger>
            <PopoverContent className="w-56" align="start">
              <div className="space-y-2">
                <div className="px-2 py-1">
                  <p className="text-sm font-medium">Data Management</p>
                  <p className="text-xs text-muted-foreground">Current mode: {demoMode ? 'Demo Data' : 'Live Data'}</p>
                </div>
                <div className="border-t pt-2 space-y-1">
                  <button
                    onClick={() => {
                      onAddExampleData();
                      setLogoMenuOpen(false);
                    }}
                    className="w-full flex items-center gap-2 px-2 py-2 text-sm hover:bg-accent rounded-md transition-colors"
                  >
                    <Database className="w-4 h-4" />
                    Add Example Data
                  </button>
                  <button
                    onClick={() => {
                      onResetAllData();
                      setLogoMenuOpen(false);
                    }}
                    className="w-full flex items-center gap-2 px-2 py-2 text-sm hover:bg-accent rounded-md transition-colors text-destructive"
                  >
                    <Trash2 className="w-4 h-4" />
                    Reset All Data
                  </button>
                </div>
                <div className="border-t pt-2 space-y-1">
                  <button
                    onClick={() => {
                      onStartNoseStudyQuestionnaire();
                      setLogoMenuOpen(false);
                    }}
                    className="w-full flex items-center gap-2 px-2 py-2 text-sm hover:bg-accent rounded-md transition-colors"
                  >
                    <FileText className="w-4 h-4" />
                    NOSE Study Questionnaire
                  </button>
                  <button
                    onClick={() => {
                      onStartQualityOfLifeSurvey();
                      setLogoMenuOpen(false);
                    }}
                    className="w-full flex items-center gap-2 px-2 py-2 text-sm hover:bg-accent rounded-md transition-colors"
                  >
                    <ClipboardCheck className="w-4 h-4" />
                    Quality of Life Survey
                  </button>
                </div>
                {isEnrolledInTrial && enrollmentStatus === 'active' && onEndClinicalTrialEnrollment && (
                  <div className="border-t pt-2 space-y-1">
                    <button
                      onClick={() => {
                        onEndClinicalTrialEnrollment();
                        setLogoMenuOpen(false);
                      }}
                      className="w-full flex items-center gap-2 px-2 py-2 text-sm hover:bg-accent rounded-md transition-colors text-destructive"
                    >
                      <Users className="w-4 h-4" />
                      End Clinical Trial Enrollment
                    </button>
                  </div>
                )}
                <div className="border-t pt-2 space-y-1">
                  <a
                    href="https://docs.google.com/document/d/1SgyrSm-TorOO8_ViabM4A1q3M4e7t_xxOzU0jbnbSq8/edit?tab=t.0"
                    target="_blank"
                    rel="noopener noreferrer"
                    onClick={() => setLogoMenuOpen(false)}
                    className="w-full flex items-center gap-2 px-2 py-2 text-sm hover:bg-accent rounded-md transition-colors"
                  >
                    <MoreVertical className="w-4 h-4" />
                    Instructions and Feedback
                  </a>
                </div>
              </div>
            </PopoverContent>
          </Popover>
          
          <h1 className="text-lg sm:text-xl md:text-lg lg:text-xl font-medium">Nosebleed Diary</h1>

          {/* User Settings Menu */}
          <Popover open={userMenuOpen} onOpenChange={setUserMenuOpen}>
            <PopoverTrigger asChild>
              <button 
                className="focus:outline-none focus:ring-2 focus:ring-ring rounded-md p-1.5 hover:bg-accent transition-colors"
                aria-label="User settings menu"
              >
                <User className="w-5 h-5" />
              </button>
            </PopoverTrigger>
            <PopoverContent className="w-64" align="end">
              <div className="space-y-2">
                <div className="px-2 py-1">
                  <p className="text-sm font-medium">User Settings</p>
                </div>
                <div className="border-t pt-2 space-y-1">
                  <button
                    onClick={() => {
                      if (onShowAccessibilityPreferences) {
                        onShowAccessibilityPreferences();
                      }
                      setUserMenuOpen(false);
                    }}
                    className="w-full flex items-center gap-2 px-2 py-2 text-sm hover:bg-accent rounded-md transition-colors text-left"
                  >
                    <User className="w-4 h-4" />
                    Accessibility and Preferences
                  </button>
                  <button
                    onClick={() => {
                      if (onShowPrivacyDataProtection) {
                        onShowPrivacyDataProtection();
                      }
                      setUserMenuOpen(false);
                    }}
                    className="w-full flex items-center gap-2 px-2 py-2 text-sm hover:bg-accent rounded-md transition-colors text-left"
                  >
                    <AlertCircle className="w-4 h-4" />
                    Privacy and Data Protection
                  </button>
                  <button
                    onClick={() => {
                      if (onShowEnrollInTrial) {
                        onShowEnrollInTrial();
                      }
                      setUserMenuOpen(false);
                    }}
                    className="w-full flex items-center gap-2 px-2 py-2 text-sm hover:bg-accent rounded-md transition-colors text-left"
                  >
                    <Users className="w-4 h-4" />
                    Enroll in Clinical Trial
                  </button>
                </div>
              </div>
            </PopoverContent>
          </Popover>
        </div>
        
        <div className="text-center">
          
          {/* Incomplete Records Warning */}
          {incompleteRecords.length > 0 && (
            <button 
              onClick={handleIncompleteRecordsClick}
              className="w-full mb-3 md:mb-2 p-3 md:p-2.5 bg-orange-100 dark:bg-orange-900/20 rounded-lg hover:bg-orange-200 dark:hover:bg-orange-900/30 transition-colors"
            >
              <div className="flex items-center gap-2 text-orange-800 dark:text-orange-200 md:text-sm">
                <AlertCircle className="w-4 h-4 md:w-3.5 md:h-3.5 flex-shrink-0" />
                <span className="text-left">
                  {incompleteRecords.length} incomplete record{incompleteRecords.length > 1 ? 's' : ''}
                </span>
                <div className="ml-auto text-orange-600 dark:text-orange-300 text-sm md:text-xs">
                  Tap to complete →
                </div>
              </div>
            </button>
          )}

          {/* Active Questionnaire Notification */}
          {showQuestionnaireButton && activeQuestionnaireName && (
            <button 
              onClick={onShowActiveQuestionnaire}
              className="w-full mb-3 md:mb-2 p-3 md:p-2.5 bg-blue-100 dark:bg-blue-900/20 rounded-lg hover:bg-blue-200 dark:hover:bg-blue-900/30 transition-colors"
            >
              <div className="flex items-center gap-2 text-blue-800 dark:text-blue-200 md:text-sm">
                <ClipboardCheck className="w-4 h-4 md:w-3.5 md:h-3.5 flex-shrink-0" />
                <span className="text-left">
                  Complete {activeQuestionnaireName}
                </span>
                <div className="ml-auto text-blue-600 dark:text-blue-300 text-sm md:text-xs">
                  Tap to continue →
                </div>
              </div>
            </button>
          )}
          
          {/* Yesterday Confirmation Banner */}
          {showNoNosebleedsButton && (
            <div className="w-full mb-3 md:mb-2 p-3 md:p-2.5 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg">
              <div className="space-y-3">
                <div className="text-yellow-900 dark:text-yellow-100 md:text-sm text-center">
                  Confirm Yesterday - {new Date(Date.now() - 24 * 60 * 60 * 1000).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}. Did you have nosebleeds?
                </div>
                <div className="flex gap-2">
                  <Button
                    onClick={onConfirmYesterdayHadNosebleeds}
                    variant="outline"
                    size="sm"
                    className="flex-1 bg-white dark:bg-gray-800 hover:bg-yellow-100 dark:hover:bg-yellow-900/40 border-yellow-300 dark:border-yellow-700"
                  >
                    Yes
                  </Button>
                  <Button
                    onClick={onConfirmNoNosebleedsYesterday}
                    variant="outline"
                    size="sm"
                    className="flex-1 bg-white dark:bg-gray-800 hover:bg-yellow-100 dark:hover:bg-yellow-900/40 border-yellow-300 dark:border-yellow-700"
                  >
                    No ✓
                  </Button>
                  <Button
                    onClick={onConfirmYesterdayDontRemember}
                    variant="outline"
                    size="sm"
                    className="flex-1 bg-white dark:bg-gray-800 hover:bg-yellow-100 dark:hover:bg-yellow-900/40 border-yellow-300 dark:border-yellow-700"
                  >
                    I don't remember
                  </Button>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Content Area */}
      <div className="flex-1 flex flex-col">
        {/* Recent Events */}
        {groupedRecords.length > 0 && (
          <div className="flex-1 px-6 pb-6 overflow-y-auto">
            <div className="space-y-4 md:space-y-3">
              {groupedRecords.map((group, groupIndex) => (
                <div key={group.label}>
                  {groupIndex > 0 && (
                    <div className="flex items-center py-2">
                      <div className="flex-1 h-px bg-border"></div>
                      <small className={`px-3 ${group.label === 'incomplete records' ? 'text-orange-600 font-medium' : 'text-muted-foreground'}`}>
                        {group.label}
                      </small>
                      <div className="flex-1 h-px bg-border"></div>
                    </div>
                  )}
                  <div className="space-y-2 md:space-y-1">
                    {/* Always show date for today and yesterday */}
                    {(group.label === 'today' || group.label === 'yesterday') && (
                      <div className="text-foreground md:text-sm mb-2 text-center font-medium">
                        {group.label === 'today' 
                          ? new Date().toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })
                          : new Date(Date.now() - 24 * 60 * 60 * 1000).toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })
                        }
                      </div>
                    )}
                    
                    {group.isEmpty ? (
                      <div className="w-full py-2 md:py-1.5 px-3 md:px-2.5 text-center">
                        <div className="text-muted-foreground md:text-sm">
                          no events {group.label}
                        </div>
                      </div>
                    ) : (
                      group.records.map((record, index) => {
                        const isIncomplete = incompleteRecords.some(ir => ir.id === record.id);
                        const hasOverlap = recordsWithOverlaps.has(record.id);
                        
                        return (
                          <EventListItem
                            key={index}
                            record={record}
                            isIncomplete={isIncomplete}
                            hasOverlap={hasOverlap}
                            onClick={() => onEditRecord(record.originalIndex)}
                            clickable={true}
                          />
                        );
                      })
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Main Action Button Area - centers content in available space */}
        <div className="flex-1 flex flex-col justify-center">
          <div className="flex-none p-8 md:p-6 flex flex-col items-center space-y-6 md:space-y-4">
            {/* Missing Data Button */}
            {showMissingDataButton && (
              <Button
                onClick={onShowMissingDataCalendar}
                variant="outline"
                className="w-full"
                size="lg"
              >
                Missing data from previous days
              </Button>
            )}

            <button 
              onClick={onStartRecording}
              className="w-full h-[25vh] min-h-[160px] md:h-[120px] md:min-h-[120px] bg-red-600 hover:bg-red-700 active:bg-red-800 text-white rounded-3xl flex flex-col items-center justify-center gap-4 md:gap-3 transition-colors shadow-xl"
            >
              <Plus className="w-12 h-12 md:w-8 md:h-8" />
              <span className="text-xl md:text-lg font-medium text-center">Record Nosebleed</span>
            </button>

            {/* Calendar Button */}
            <Button
              onClick={onShowCalendar}
              variant="outline"
              size="lg"
              className="w-full flex items-center justify-center gap-2"
            >
              <Calendar className="w-5 h-5" />
              Calendar
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}