import React, { useState } from 'react';
import { HomeScreen } from './components/HomeScreen';
import { RecordingFlow } from './components/RecordingFlow';
import { CalendarOverlay } from './components/CalendarOverlay';
import { MissingDataCalendar } from './components/MissingDataCalendar';
import { DaySelectionScreen } from './components/DaySelectionScreen';
import { YesterdayOptionsScreen } from './components/YesterdayOptionsScreen';
import { DateRecordsScreen } from './components/DateRecordsScreen';
import { QuestionnaireFlow } from './components/QuestionnaireFlow';
import { ClinicalTrialEnrollment } from './components/ClinicalTrialEnrollment';
import { ProfileScreen } from './components/ProfileScreen';
import { SettingsScreen } from './components/SettingsScreen';
import { getQuestionnaireByName, QuestionnaireResponse } from './data/questionnaires';
import { SurveyViewScreen } from './components/SurveyViewScreen';
import clinicalTrialLogo from 'figma:asset/4884d92ca92ef779f1cec2253216537f9b341e00.png';
import cureHHTLogo from 'figma:asset/ba09a9637ac0ff172dab598ce95c889db4cb245f.png';

export type NosebleedRecord = {
  id: string;
  date: Date;
  startTime?: Date;
  endTime?: Date;
  severity?: string;
  notes?: string;
  isNoNosebleedsEvent?: boolean;
  isUnknownEvent?: boolean;
  isIncomplete?: boolean;
  isSurveyEvent?: boolean;
  surveyName?: string;
};

export default function App() {
  const [currentScreen, setCurrentScreen] = useState<'home' | 'recording' | 'editing' | 'profile' | 'settings' | 'clinical-trial-enrollment' | 'missing-data' | 'day-selection' | 'date-records' | 'questionnaire' | 'survey-view'>('home');
  const [editingRecordIndex, setEditingRecordIndex] = useState<number | null>(null);
  const [showCalendar, setShowCalendar] = useState(false);
  const [showMissingDataCalendar, setShowMissingDataCalendar] = useState(false);
  const [showYesterdayOptions, setShowYesterdayOptions] = useState(false);
  const [selectedDate, setSelectedDate] = useState<Date | null>(null);
  const [demoMode, setDemoMode] = useState(false); // Toggle between demo data and fresh install
  
  // Clinical trial enrollment state
  const [isEnrolledInTrial, setIsEnrolledInTrial] = useState(false);
  const [enrollmentCode, setEnrollmentCode] = useState<string | null>(null);
  const [enrollmentDateTime, setEnrollmentDateTime] = useState<Date | null>(null);
  const [enrollmentEndDateTime, setEnrollmentEndDateTime] = useState<Date | null>(null);
  const [enrollmentStatus, setEnrollmentStatus] = useState<'active' | 'ended'>('active');
  
  // CureHHT sharing state
  const [isSharingWithCureHHT, setIsSharingWithCureHHT] = useState(false);
  
  // User profile state
  const [userName, setUserName] = useState("User's Name");
  
  // Questionnaire state
  const [activeQuestionnaire, setActiveQuestionnaire] = useState<string | null>(null);
  const [completedQuestionnaires, setCompletedQuestionnaires] = useState<QuestionnaireResponse[]>(() => 
    demoMode ? generateSampleQuestionnaires() : []
  );
  
  // Survey view state
  const [viewingSurveyId, setViewingSurveyId] = useState<string | null>(null);

  const [currentRecordData, setCurrentRecordData] = useState({
    date: new Date(),
    startTime: null,
    endTime: null,
    severity: null,
  });

  const generateId = () => {
    return Date.now().toString() + Math.random().toString(36).substr(2, 9);
  };

  // Function to generate sample completed questionnaires
  const generateSampleQuestionnaires = (): QuestionnaireResponse[] => {
    const now = new Date();
    return [
      {
        questionnaireId: 'sample-nose-1',
        questionnaireName: 'NOSE HHT',
        completedAt: new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000), // 3 days ago
        responses: {
          'nose_physical_1': 'Moderate difficulty',
          'nose_physical_2': 'Mild difficulty',
          'nose_physical_3': 'Severe difficulty',
          'nose_physical_4': 'No difficulty',
          'nose_physical_5': 'Moderate difficulty',
          'nose_functional_1': 'Mild difficulty',
          'nose_functional_2': 'Moderate difficulty',
          'nose_functional_3': 'Severe difficulty',
          'nose_functional_4': 'No difficulty',
          'nose_functional_5': 'Mild difficulty',
          'nose_functional_6': 'Moderate difficulty',
          'nose_functional_7': 'Mild difficulty',
          'nose_functional_8': 'No difficulty',
          'nose_functional_9': 'Moderate difficulty',
          'nose_functional_10': 'Mild difficulty',
          'nose_functional_11': 'Severe difficulty',
          'nose_functional_12': 'Moderate difficulty',
          'nose_functional_13': 'Mild difficulty',
          'nose_functional_14': 'No difficulty',
          'nose_emotional_1': 'Moderate difficulty',
          'nose_emotional_2': 'Mild difficulty',
          'nose_emotional_3': 'Severe difficulty'
        }
      },
      {
        questionnaireId: 'sample-qol-1',
        questionnaireName: 'Quality of Life Survey',
        completedAt: new Date(now.getTime() - 1 * 24 * 60 * 60 * 1000), // Yesterday
        responses: {
          'qol_general_1': 'Good',
          'qol_general_2': 'Satisfied',
          'qol_general_3': 'Sometimes',
          'qol_general_4': 'Rarely',
          'qol_general_5': 'Often',
          'qol_physical_1': 'Moderate impact',
          'qol_physical_2': 'Mild impact',
          'qol_physical_3': 'Significant impact',
          'qol_physical_4': 'No impact',
          'qol_emotional_1': 'Sometimes',
          'qol_emotional_2': 'Rarely',
          'qol_emotional_3': 'Often',
          'qol_social_1': 'Moderate impact',
          'qol_social_2': 'Mild impact',
          'qol_social_3': 'No impact'
        }
      }
    ];
  };

  const getIncompleteRecords = () => {
    return records.filter(record => {
      if (record.isNoNosebleedsEvent || record.isUnknownEvent || record.isSurveyEvent) {
        return false;
      }
      
      // Check if notes are required for this record (only for active enrollment)
      const requiresNotes = isEnrolledInTrial && enrollmentStatus === 'active' && enrollmentDateTime && (() => {
        const recordStartTime = record.startTime || record.date || new Date();
        return recordStartTime >= enrollmentDateTime;
      })();
      
      return record.isIncomplete || 
             !record.endTime || 
             !record.severity || 
             (requiresNotes && !record.notes);
    });
  };

  // Function to generate sample data
  const generateSampleData = (): NosebleedRecord[] => {
    const now = new Date();
    return [
      {
        id: '1',
        date: new Date(now.getTime() - 6 * 24 * 60 * 60 * 1000), // 6 days ago
        startTime: new Date(now.getTime() - 6 * 24 * 60 * 60 * 1000),
        endTime: new Date(now.getTime() - 6 * 24 * 60 * 60 * 1000 + 3 * 60 * 1000),
        severity: 'Spotting'
      },
      {
        id: '2',
        date: new Date(now.getTime() - 5 * 24 * 60 * 60 * 1000), // 5 days ago
        startTime: new Date(now.getTime() - 5 * 24 * 60 * 60 * 1000),
        endTime: new Date(now.getTime() - 5 * 24 * 60 * 60 * 1000 + 12 * 60 * 1000),
        severity: 'Dripping'
      },
      {
        id: '3',
        date: new Date(now.getTime() - 4 * 24 * 60 * 60 * 1000), // 4 days ago
        startTime: new Date(now.getTime() - 4 * 24 * 60 * 60 * 1000),
        endTime: new Date(now.getTime() - 4 * 24 * 60 * 60 * 1000 + 18 * 60 * 1000),
        severity: 'Dripping quickly'
      },
      {
        id: '4',
        date: new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000), // 3 days ago
        startTime: new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000),
        endTime: new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000 + 25 * 60 * 1000),
        severity: 'Steady stream'
      },
      {
        id: '5',
        date: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000), // 2 days ago
        startTime: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000),
        endTime: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000 + 35 * 60 * 1000),
        severity: 'Pouring'
      },
      {
        id: '6',
        date: new Date(now.getTime() - 24 * 60 * 60 * 1000), // Yesterday
        startTime: new Date(now.getTime() - 24 * 60 * 60 * 1000),
        isNoNosebleedsEvent: true,
      },
      {
        id: '7',
        date: new Date(now.getTime() - 6 * 60 * 60 * 1000), // 6 hours ago (today)
        startTime: new Date(now.getTime() - 6 * 60 * 60 * 1000),
        endTime: new Date(now.getTime() - 6 * 60 * 60 * 1000 + 45 * 60 * 1000), // 45 minutes
        severity: 'Gushing'
      },
      {
        id: '8',
        date: new Date(now.getTime() - 2 * 60 * 60 * 1000), // 2 hours ago (today)
        startTime: new Date(now.getTime() - 2 * 60 * 60 * 1000),
        endTime: new Date(now.getTime() - 2 * 60 * 60 * 1000 + 8 * 60 * 1000), // 8 minutes
        severity: 'Dripping'
      },
      {
        id: '9',
        date: new Date(now.getTime() - 1 * 60 * 60 * 1000), // 1 hour ago (incomplete)
        startTime: new Date(now.getTime() - 1 * 60 * 60 * 1000),
        isIncomplete: true
        // Missing endTime and severity to demonstrate incomplete record
      },
      // Add an overlapping event for testing
      {
        id: '10',
        date: new Date(now.getTime() - 6 * 60 * 60 * 1000), // 6 hours ago (today) - overlaps with id: '7'
        startTime: new Date(now.getTime() - 6 * 60 * 60 * 1000 + 20 * 60 * 1000), // Starts 20 min after event 7
        endTime: new Date(now.getTime() - 6 * 60 * 60 * 1000 + 50 * 60 * 1000), // Ends 50 min after event 7
        severity: 'Spotting'
      },
      // Add sample survey events
      {
        id: '11',
        date: new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000), // 3 days ago
        startTime: new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000),
        endTime: new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000),
        isSurveyEvent: true,
        surveyName: 'NOSE HHT'
      },
      {
        id: '12',
        date: new Date(now.getTime() - 1 * 24 * 60 * 60 * 1000), // Yesterday
        startTime: new Date(now.getTime() - 1 * 24 * 60 * 60 * 1000),
        endTime: new Date(now.getTime() - 1 * 24 * 60 * 60 * 1000),
        isSurveyEvent: true,
        surveyName: 'Quality of Life Survey'
      }
    ];
  };
  
  // Records state - starts with demo data or empty based on demo mode
  const [records, setRecords] = useState<NosebleedRecord[]>(() => 
    demoMode ? generateSampleData() : []
  );

  // Update records when demo mode changes
  React.useEffect(() => {
    if (demoMode && records.length === 0) {
      setRecords(generateSampleData());
      setCompletedQuestionnaires(generateSampleQuestionnaires());
    }
  }, [demoMode]);

  const handleStartRecording = () => {
    setSelectedDate(new Date()); // Default to today
    setCurrentScreen('recording');
  };

  const handleUpdateProfile = () => {
    setCurrentScreen('profile');
  };

  const toggleDemoMode = () => {
    const newDemoMode = !demoMode;
    setDemoMode(newDemoMode);
    
    // Update records based on new demo mode
    if (newDemoMode) {
      setRecords(generateSampleData());
      setCompletedQuestionnaires(generateSampleQuestionnaires());
    } else {
      setRecords([]);
      setCompletedQuestionnaires([]);
    }
    
    // Reset any open screens/modals
    setCurrentScreen('home');
    setSelectedDate(null);
    setShowCalendar(false);
    setShowMissingDataCalendar(false);
    setShowYesterdayOptions(false);
    setEditingRecordIndex(null);
    setActiveQuestionnaire(null);
    setViewingSurveyId(null);
  };

  const handleResetAllData = () => {
    setRecords([]);
    setDemoMode(false);
    setCompletedQuestionnaires([]);
    setIsEnrolledInTrial(false);
    setEnrollmentCode(null);
    setEnrollmentDateTime(null);
    setEnrollmentEndDateTime(null);
    setEnrollmentStatus('active');
    setIsSharingWithCureHHT(false);
    setUserName("User's Name");
    
    // Reset any open screens/modals
    setCurrentScreen('home');
    setSelectedDate(null);
    setShowCalendar(false);
    setShowMissingDataCalendar(false);
    setShowYesterdayOptions(false);
    setEditingRecordIndex(null);
    setActiveQuestionnaire(null);
    setViewingSurveyId(null);
  };

  const handleAddExampleData = () => {
    setRecords(generateSampleData());
    setCompletedQuestionnaires(generateSampleQuestionnaires());
    setDemoMode(true);
    
    // Reset any open screens/modals
    setCurrentScreen('home');
    setSelectedDate(null);
    setShowCalendar(false);
    setShowMissingDataCalendar(false);
    setShowYesterdayOptions(false);
    setEditingRecordIndex(null);
    setActiveQuestionnaire(null);
    setViewingSurveyId(null);
  };

  const handleBackToHome = (incompleteRecord?: NosebleedRecord) => {
    // Save incomplete record if provided and we're actually in a recording context
    if (incompleteRecord && (currentScreen === 'recording' || currentScreen === 'editing')) {
      // Ensure the record has a valid date
      const recordWithValidDate = {
        ...incompleteRecord,
        date: incompleteRecord.date || new Date(),
        startTime: incompleteRecord.startTime || new Date()
      };
      setRecords(prev => [...prev, recordWithValidDate]);
    }
    
    setCurrentScreen('home');
    setSelectedDate(null);
    setShowYesterdayOptions(false);
  };

  // Questionnaire handlers
  const handleStartNoseStudyQuestionnaire = () => {
    setActiveQuestionnaire('NOSE HHT');
    // Don't immediately go to questionnaire screen - let the notification button appear
  };

  const handleStartQualityOfLifeSurvey = () => {
    setActiveQuestionnaire('Quality of Life Survey');
    // Don't immediately go to questionnaire screen - let the notification button appear
  };

  const handleShowActiveQuestionnaire = () => {
    if (activeQuestionnaire) {
      setCurrentScreen('questionnaire');
    }
  };

  const handleQuestionnaireComplete = (responses: Record<string, string>) => {
    if (activeQuestionnaire) {
      const completedAt = new Date();
      
      const response: QuestionnaireResponse = {
        questionnaireId: generateId(),
        questionnaireName: activeQuestionnaire,
        completedAt: completedAt,
        responses
      };
      
      // Create a survey event record
      const surveyRecord: NosebleedRecord = {
        id: generateId(),
        date: completedAt,
        startTime: completedAt,
        endTime: completedAt, // Survey events are instantaneous
        isSurveyEvent: true,
        surveyName: activeQuestionnaire
      };
      
      setCompletedQuestionnaires(prev => [...prev, response]);
      setRecords(prev => [...prev, surveyRecord]);
      setActiveQuestionnaire(null);
      setCurrentScreen('home');
    }
  };

  const handleQuestionnaireCancel = () => {
    // Only allow cancellation from the very first preamble screen
    // Once user progresses past the first preamble, they must complete the questionnaire
    setActiveQuestionnaire(null);
    setCurrentScreen('home');
  };

  // Clinical trial enrollment handlers
  const handleStartClinicalTrialEnrollment = () => {
    setCurrentScreen('clinical-trial-enrollment');
  };

  const handleClinicalTrialEnrollment = (code: string) => {
    const enrollmentTime = new Date();
    setIsEnrolledInTrial(true);
    setEnrollmentCode(code);
    setEnrollmentDateTime(enrollmentTime);
    setEnrollmentStatus('active');
    
    // Clear any state that might cause incomplete record creation
    setEditingRecordIndex(null);
    setSelectedDate(null);
    
    setCurrentScreen('profile'); // Return to profile screen to show success
  };

  const handleEndClinicalTrialEnrollment = () => {
    const endTime = new Date();
    setEnrollmentStatus('ended');
    setEnrollmentEndDateTime(endTime);
  };

  // Settings navigation handler
  const handleShowSettings = () => {
    setCurrentScreen('settings');
  };

  // CureHHT sharing handlers
  const handleShareWithCureHHT = () => {
    setIsSharingWithCureHHT(true);
    // No screen change needed - just toggle the state
  };

  const handleStopSharingWithCureHHT = () => {
    setIsSharingWithCureHHT(false);
    // No screen change needed - just toggle the state
  };

  // User name handler
  const handleUpdateUserName = (newName: string) => {
    setUserName(newName);
  };

  const handleShowCalendar = () => {
    setShowCalendar(true);
  };

  const handleCloseCalendar = () => {
    setShowCalendar(false);
  };

  const handleDateSelect = (date: Date) => {
    setSelectedDate(date);
    
    // If the selected date has no existing records, show day selection options
    if (!hasRecordsForDate(date)) {
      setCurrentScreen('day-selection');
    } else {
      // If records exist, show the date records screen
      setCurrentScreen('date-records');
    }
    
    setShowCalendar(false);
  };

  const handleShowMissingDataCalendar = () => {
    setShowMissingDataCalendar(true);
  };

  const handleCloseMissingDataCalendar = () => {
    setShowMissingDataCalendar(false);
  };

  const handleMissingDateSelect = (date: Date) => {
    setSelectedDate(date);
    setCurrentScreen('day-selection');
    setShowMissingDataCalendar(false);
  };

  const handleDayOptionSelect = (option: 'add-event' | 'no-nosebleeds' | 'unknown') => {
    if (option === 'add-event') {
      setCurrentScreen('recording');
    } else {
      const record: NosebleedRecord = {
        id: generateId(),
        date: selectedDate!,
        startTime: new Date(selectedDate!.getTime()),
        isNoNosebleedsEvent: option === 'no-nosebleeds',
        isUnknownEvent: option === 'unknown',
      };
      
      setRecords(prev => [...prev, record]);
      setCurrentScreen('home');
      setSelectedDate(null);
    }
  };

  const handleConfirmNoNosebleedsYesterday = () => {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    yesterday.setHours(12, 0, 0, 0); // Set to noon to avoid timezone issues
    
    const record: NosebleedRecord = {
      id: generateId(),
      date: yesterday,
      startTime: yesterday,
      isNoNosebleedsEvent: true,
      isUnknownEvent: false,
    };
    
    setRecords(prev => [...prev, record]);
  };

  const handleConfirmYesterdayHadNosebleeds = () => {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    yesterday.setHours(12, 0, 0, 0); // Set to noon to avoid timezone issues
    
    // Start recording flow with yesterday's date
    setSelectedDate(yesterday);
    setCurrentScreen('recording');
    setCurrentRecordData({
      date: yesterday,
      startTime: null,
      endTime: null,
      severity: null,
    });
  };

  const handleConfirmYesterdayDontRemember = () => {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    yesterday.setHours(12, 0, 0, 0); // Set to noon to avoid timezone issues
    
    const record: NosebleedRecord = {
      id: generateId(),
      date: yesterday,
      startTime: yesterday,
      isNoNosebleedsEvent: false,
      isUnknownEvent: true,
    };
    
    setRecords(prev => [...prev, record]);
  };

  const handleYesterdayOptionSelect = (option: 'no-nosebleeds' | 'unknown') => {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    yesterday.setHours(12, 0, 0, 0); // Set to noon to avoid timezone issues
    
    const record: NosebleedRecord = {
      id: generateId(),
      date: yesterday,
      startTime: yesterday,
      isNoNosebleedsEvent: option === 'no-nosebleeds',
      isUnknownEvent: option === 'unknown',
    };
    
    setRecords(prev => [...prev, record]);
    setShowYesterdayOptions(false);
  };

  // Helper function to check if there were any events yesterday
  const hasEventsYesterday = () => {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    
    return records.some(record => {
      if (!record.date || !(record.date instanceof Date)) {
        return false;
      }
      const recordDate = new Date(record.date);
      return recordDate.toDateString() === yesterday.toDateString();
    });
  };

  // Helper function to get the earliest record date
  const getEarliestRecordDate = () => {
    if (records.length === 0) return null;
    
    // Filter out records with invalid dates first
    const validRecords = records.filter(record => record.date && record.date instanceof Date);
    if (validRecords.length === 0) return null;
    
    return validRecords.reduce((earliest, record) => {
      return record.date < earliest ? record.date : earliest;
    }, validRecords[0].date);
  };

  // Helper function to check if two events overlap
  const eventsOverlap = (event1: NosebleedRecord, event2: NosebleedRecord) => {
    // Skip if either event is a special event type or incomplete without end time
    if (event1.isNoNosebleedsEvent || event1.isUnknownEvent || event1.isSurveyEvent ||
        event2.isNoNosebleedsEvent || event2.isUnknownEvent || event2.isSurveyEvent ||
        !event1.endTime || !event2.endTime) {
      return false;
    }

    // Check for invalid dates
    if (!event1.date || !event2.date || !event1.startTime || !event2.startTime ||
        !(event1.date instanceof Date) || !(event2.date instanceof Date) ||
        !(event1.startTime instanceof Date) || !(event2.startTime instanceof Date) ||
        !(event1.endTime instanceof Date) || !(event2.endTime instanceof Date)) {
      return false;
    }

    // Check if events are on different days
    if (event1.date.toDateString() !== event2.date.toDateString()) {
      return false;
    }

    const start1 = event1.startTime.getTime();
    const end1 = event1.endTime.getTime();
    const start2 = event2.startTime.getTime();
    const end2 = event2.endTime.getTime();

    // Events overlap if one starts before the other ends
    return start1 < end2 && start2 < end1;
  };

  // Helper function to get overlapping events for a specific record
  const getOverlappingEvents = (targetRecord: NosebleedRecord) => {
    return records.filter(record => 
      record.id !== targetRecord.id && eventsOverlap(targetRecord, record)
    );
  };

  // Helper function to get all records that have overlaps
  const getRecordsWithOverlaps = () => {
    const recordsWithOverlaps = new Set<string>();
    
    for (let i = 0; i < records.length; i++) {
      for (let j = i + 1; j < records.length; j++) {
        if (eventsOverlap(records[i], records[j])) {
          recordsWithOverlaps.add(records[i].id);
          recordsWithOverlaps.add(records[j].id);
        }
      }
    }
    
    return recordsWithOverlaps;
  };

  // Helper function to check if a date has any records
  const hasRecordsForDate = (date: Date) => {
    return records.some(record => {
      if (!record.date || !(record.date instanceof Date)) {
        return false;
      }
      const recordDate = new Date(record.date);
      return recordDate.toDateString() === date.toDateString();
    });
  };

  // Helper function to get missing data days
  const getMissingDataDays = () => {
    const earliestDate = getEarliestRecordDate();
    if (!earliestDate) return [];
    
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    yesterday.setHours(0, 0, 0, 0);
    
    const earliest = new Date(earliestDate);
    earliest.setHours(0, 0, 0, 0);
    
    const missingDays: Date[] = [];
    const current = new Date(earliest);
    
    while (current <= yesterday) {
      const hasRecord = records.some(record => {
        if (!record.date || !(record.date instanceof Date)) {
          return false;
        }
        const recordDate = new Date(record.date);
        recordDate.setHours(0, 0, 0, 0);
        return recordDate.getTime() === current.getTime();
      });
      
      if (!hasRecord) {
        missingDays.push(new Date(current));
      }
      
      current.setDate(current.getDate() + 1);
    }
    
    return missingDays;
  };

  // Check if we should show the missing data button
  const shouldShowMissingDataButton = () => {
    return hasEventsYesterday() && getMissingDataDays().length > 0;
  };

  // Check if we should show the questionnaire notification button
  const shouldShowQuestionnaireButton = () => {
    return activeQuestionnaire !== null;
  };

  const handleSaveRecord = (record: NosebleedRecord) => {
    // Validate duration - prevent negative durations
    if (record.startTime && record.endTime && record.endTime <= record.startTime) {
      // Don't save the record, the RecordingFlow should handle this validation
      console.error('Cannot save record with negative duration');
      return;
    }

    // Ensure the record has valid dates
    const validatedRecord = {
      ...record,
      date: record.date || new Date(),
      startTime: record.startTime || new Date()
    };

    setRecords(prev => {
      // Remove any "no nosebleeds" or "unknown" events for the same date when adding a real nosebleed event
      // Don't remove survey events as they can coexist with nosebleed events
      const filteredRecords = prev.filter(existingRecord => {
        if (!existingRecord.date || !validatedRecord.date || 
            !(existingRecord.date instanceof Date) || !(validatedRecord.date instanceof Date)) {
          return true; // Keep records with invalid dates
        }
        const isSameDate = existingRecord.date.toDateString() === validatedRecord.date.toDateString();
        return !(isSameDate && (existingRecord.isNoNosebleedsEvent || existingRecord.isUnknownEvent));
      });
      
      // Ensure the record has an ID and remove isIncomplete flag if record is complete
      const recordWithId = {
        ...validatedRecord,
        id: validatedRecord.id || generateId(),
        isIncomplete: (!validatedRecord.severity || !validatedRecord.endTime) ? validatedRecord.isIncomplete : undefined
      };
      
      return [...filteredRecords, recordWithId];
    });
    setCurrentScreen('home');
    setSelectedDate(null);
  };

  const handleEditRecord = (index: number) => {
    // Validate index bounds
    if (index < 0 || index >= records.length) {
      console.error('Invalid record index for editing:', index, 'Records length:', records.length);
      return;
    }
    
    const record = records[index];
    
    // Handle survey events - take to view-only survey screen
    if (record.isSurveyEvent && record.surveyName) {
      // Find the corresponding completed questionnaire
      const completedQuestionnaire = completedQuestionnaires.find(q => 
        q.questionnaireName === record.surveyName && 
        Math.abs(q.completedAt.getTime() - (record.startTime?.getTime() || record.date.getTime())) < 5000 // Within 5 seconds
      );
      
      if (completedQuestionnaire) {
        setViewingSurveyId(completedQuestionnaire.questionnaireId);
        setCurrentScreen('survey-view');
      }
      return;
    }
    
    // Don't allow editing of "no nosebleeds" or "unknown" events
    if (record.isNoNosebleedsEvent || record.isUnknownEvent) {
      return;
    }
    
    setEditingRecordIndex(index);
    setCurrentScreen('editing');
  };

  const handleEditRecordFromDateScreen = (index: number) => {
    handleEditRecord(index);
  };

  const handleAddNewEventFromDateScreen = () => {
    setCurrentScreen('recording');
  };

  const handleUpdateRecord = (updatedRecord: NosebleedRecord) => {
    // Validate duration - prevent negative durations
    if (updatedRecord.startTime && updatedRecord.endTime && updatedRecord.endTime <= updatedRecord.startTime) {
      // Don't save the record, the RecordingFlow should handle this validation
      console.error('Cannot update record with negative duration');
      return;
    }

    // Ensure the record has valid dates
    const validatedRecord = {
      ...updatedRecord,
      date: updatedRecord.date || new Date(),
      startTime: updatedRecord.startTime || new Date()
    };

    if (editingRecordIndex !== null) {
      setRecords(prev => {
        // Validate that the editingRecordIndex is still valid
        if (editingRecordIndex < 0 || editingRecordIndex >= prev.length) {
          console.error('Invalid editing record index:', editingRecordIndex, 'Records length:', prev.length);
          // Find the record by ID instead
          const recordIndex = prev.findIndex(record => record.id === updatedRecord.id);
          if (recordIndex === -1) {
            console.error('Could not find record to update with ID:', updatedRecord.id);
            return prev;
          }
          
          // Update using the found index
          const finalRecord = {
            ...validatedRecord,
            isIncomplete: (!validatedRecord.severity || !validatedRecord.endTime) ? validatedRecord.isIncomplete : undefined
          };
          
          let updatedRecords = prev.map((record, index) => 
            index === recordIndex ? finalRecord : record
          );
          
          // If we're updating a record to be a real nosebleed event,
          // remove any other "no nosebleeds" or "unknown" events for the same date
          if (!finalRecord.isNoNosebleedsEvent && !finalRecord.isUnknownEvent) {
            updatedRecords = updatedRecords.filter(record => {
              if (!record.date || !finalRecord.date || 
                  !(record.date instanceof Date) || !(finalRecord.date instanceof Date)) {
                return true; // Keep records with invalid dates
              }
              const isSameDate = record.date.toDateString() === finalRecord.date.toDateString();
              return !(isSameDate && (record.isNoNosebleedsEvent || record.isUnknownEvent) && record !== finalRecord);
            });
          }
          
          return updatedRecords;
        }
        
        // Remove isIncomplete flag if record now has all required data
        const finalRecord = {
          ...validatedRecord,
          isIncomplete: (!validatedRecord.severity || !validatedRecord.endTime) ? validatedRecord.isIncomplete : undefined
        };
        
        let updatedRecords = prev.map((record, index) => 
          index === editingRecordIndex ? finalRecord : record
        );
        
        // If we're updating a record to be a real nosebleed event,
        // remove any other "no nosebleeds" or "unknown" events for the same date
        // Don't remove survey events as they can coexist with nosebleed events
        if (!finalRecord.isNoNosebleedsEvent && !finalRecord.isUnknownEvent && !finalRecord.isSurveyEvent) {
          updatedRecords = updatedRecords.filter(record => {
            if (!record.date || !finalRecord.date || 
                !(record.date instanceof Date) || !(finalRecord.date instanceof Date)) {
              return true; // Keep records with invalid dates
            }
            const isSameDate = record.date.toDateString() === finalRecord.date.toDateString();
            return !(isSameDate && (record.isNoNosebleedsEvent || record.isUnknownEvent) && record !== finalRecord);
          });
        }
        
        return updatedRecords;
      });
    }
    setEditingRecordIndex(null);
    setCurrentScreen('home');
    setSelectedDate(null);
  };

  const handleDeleteRecord = (reason: string) => {
    if (editingRecordIndex !== null) {
      // Validate index bounds before deleting
      if (editingRecordIndex < 0 || editingRecordIndex >= records.length) {
        console.error('Invalid record index for deletion:', editingRecordIndex, 'Records length:', records.length);
        setEditingRecordIndex(null);
        setCurrentScreen('home');
        setSelectedDate(null);
        return;
      }
      
      // Log the deletion reason (in a real app, this might be sent to analytics or stored)
      console.log('Deleting record with reason:', reason);
      
      // Deleting an existing record
      setRecords(prev => prev.filter((_, index) => index !== editingRecordIndex));
      setEditingRecordIndex(null);
    }
    // For new records, just cancel (no deletion needed)
    setCurrentScreen('home');
    setSelectedDate(null);
  };

  if (currentScreen === 'questionnaire' && activeQuestionnaire) {
    const questionnaireData = getQuestionnaireByName(activeQuestionnaire);
    if (!questionnaireData) {
      // Fallback if questionnaire not found
      setActiveQuestionnaire(null);
      setCurrentScreen('home');
      return null;
    }

    return (
      <div className="min-h-screen bg-background">
        <div className="mx-auto max-w-md">
          <QuestionnaireFlow
            questionnaire={questionnaireData}
            onComplete={handleQuestionnaireComplete}
            onCancel={handleQuestionnaireCancel}
          />
        </div>
      </div>
    );
  }

  if (currentScreen === 'survey-view' && viewingSurveyId) {
    const completedQuestionnaire = completedQuestionnaires.find(q => q.questionnaireId === viewingSurveyId);
    if (!completedQuestionnaire) {
      // Fallback if questionnaire response not found
      setViewingSurveyId(null);
      setCurrentScreen('home');
      return null;
    }

    const questionnaireData = getQuestionnaireByName(completedQuestionnaire.questionnaireName);
    if (!questionnaireData) {
      // Fallback if questionnaire data not found
      setViewingSurveyId(null);
      setCurrentScreen('home');
      return null;
    }

    return (
      <div className="min-h-screen bg-background">
        <div className="mx-auto max-w-md">
          <SurveyViewScreen
            questionnaire={questionnaireData}
            response={completedQuestionnaire}
            onBack={() => {
              setViewingSurveyId(null);
              setCurrentScreen('home');
            }}
          />
        </div>
      </div>
    );
  }

  if (currentScreen === 'recording') {
    return (
      <div className="min-h-screen bg-background">
        <div className="mx-auto max-w-md">
          <RecordingFlow 
            onSave={handleSaveRecord}
            onBack={handleBackToHome}
            onDelete={handleDeleteRecord}
            initialDate={selectedDate || new Date()}
            recordId={generateId()}
            records={records}
            getOverlappingEvents={getOverlappingEvents}
            isEnrolledInTrial={isEnrolledInTrial}
            enrollmentDateTime={enrollmentDateTime}
          />
        </div>
      </div>
    );
  }

  if (currentScreen === 'editing' && editingRecordIndex !== null) {
    // Validate that the editingRecordIndex is still valid
    if (editingRecordIndex < 0 || editingRecordIndex >= records.length) {
      console.error('Invalid editing record index, returning to home:', editingRecordIndex, 'Records length:', records.length);
      // Reset state and return to home
      setEditingRecordIndex(null);
      setCurrentScreen('home');
      setSelectedDate(null);
      return (
        <div className="min-h-screen bg-background">
          <div className="mx-auto max-w-md">
            <HomeScreen 
              onStartRecording={handleStartRecording}
              onUpdateProfile={handleUpdateProfile}
              onEditRecord={handleEditRecord}
              onShowCalendar={handleShowCalendar}
              onConfirmNoNosebleedsYesterday={handleConfirmNoNosebleedsYesterday}
              onShowMissingDataCalendar={handleShowMissingDataCalendar}
              onStartNoseStudyQuestionnaire={handleStartNoseStudyQuestionnaire}
              onStartQualityOfLifeSurvey={handleStartQualityOfLifeSurvey}
              onShowActiveQuestionnaire={handleShowActiveQuestionnaire}
              showNoNosebleedsButton={!hasEventsYesterday()}
              showMissingDataButton={shouldShowMissingDataButton()}
              showQuestionnaireButton={shouldShowQuestionnaireButton()}
              activeQuestionnaireName={activeQuestionnaire}
              incompleteRecords={getIncompleteRecords()}
              recordsWithOverlaps={getRecordsWithOverlaps()}
              demoMode={demoMode}
              onToggleDemoMode={toggleDemoMode}
              onResetAllData={handleResetAllData}
              onAddExampleData={handleAddExampleData}
              records={records}
              logoSrc={isEnrolledInTrial && enrollmentStatus === 'active' ? clinicalTrialLogo : cureHHTLogo}
              logoAlt={isEnrolledInTrial && enrollmentStatus === 'active' ? "Clinical Trial" : "CureHHT"}
              isSharingWithCureHHT={isSharingWithCureHHT}
            />
          </div>
        </div>
      );
    }
    
    return (
      <div className="min-h-screen bg-background">
        <div className="mx-auto max-w-md">
          <RecordingFlow 
            onSave={handleUpdateRecord}
            onBack={handleBackToHome}
            onDelete={handleDeleteRecord}
            existingRecord={records[editingRecordIndex]}
            initialDate={records[editingRecordIndex].date}
            recordId={records[editingRecordIndex].id}
            records={records}
            getOverlappingEvents={getOverlappingEvents}
            isEnrolledInTrial={isEnrolledInTrial}
            enrollmentDateTime={enrollmentDateTime}
          />
        </div>
      </div>
    );
  }

  if (currentScreen === 'day-selection' && selectedDate) {
    return (
      <div className="min-h-screen bg-background">
        <div className="mx-auto max-w-md">
          <DaySelectionScreen
            date={selectedDate}
            onBack={handleBackToHome}
            onOptionSelect={handleDayOptionSelect}
          />
        </div>
      </div>
    );
  }

  if (currentScreen === 'date-records' && selectedDate) {
    return (
      <div className="min-h-screen bg-background">
        <div className="mx-auto max-w-md">
          <DateRecordsScreen
            date={selectedDate}
            records={records}
            incompleteRecords={getIncompleteRecords()}
            recordsWithOverlaps={getRecordsWithOverlaps()}
            onBack={handleBackToHome}
            onEditRecord={handleEditRecordFromDateScreen}
            onAddNewEvent={handleAddNewEventFromDateScreen}
          />
        </div>
      </div>
    );
  }

  if (showYesterdayOptions) {
    return (
      <div className="min-h-screen bg-background">
        <div className="mx-auto max-w-md">
          <YesterdayOptionsScreen
            onBack={handleBackToHome}
            onOptionSelect={handleYesterdayOptionSelect}
          />
        </div>
      </div>
    );
  }

  if (currentScreen === 'profile') {
    return (
      <div className="min-h-screen bg-background">
        <div className="mx-auto max-w-md">
          <ProfileScreen
            onBack={handleBackToHome}
            onStartClinicalTrialEnrollment={handleStartClinicalTrialEnrollment}
            onShowSettings={handleShowSettings}
            onShareWithCureHHT={handleShareWithCureHHT}
            onStopSharingWithCureHHT={handleStopSharingWithCureHHT}
            isEnrolledInTrial={isEnrolledInTrial}
            enrollmentCode={enrollmentCode}
            enrollmentDateTime={enrollmentDateTime}
            enrollmentEndDateTime={enrollmentEndDateTime}
            enrollmentStatus={enrollmentStatus}
            isSharingWithCureHHT={isSharingWithCureHHT}
            userName={userName}
            onUpdateUserName={handleUpdateUserName}
          />
        </div>
      </div>
    );
  }

  if (currentScreen === 'settings') {
    return (
      <div className="min-h-screen bg-background">
        <div className="mx-auto max-w-md">
          <SettingsScreen
            onBack={() => setCurrentScreen('profile')}
          />
        </div>
      </div>
    );
  }

  if (currentScreen === 'clinical-trial-enrollment') {
    return (
      <div className="min-h-screen bg-background">
        <div className="mx-auto max-w-md">
          <ClinicalTrialEnrollment
            onBack={() => setCurrentScreen('profile')}
            onEnroll={handleClinicalTrialEnrollment}
          />
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="mx-auto max-w-md">
        <HomeScreen 
          onStartRecording={handleStartRecording}
          onUpdateProfile={handleUpdateProfile}
          onEditRecord={handleEditRecord}
          onShowCalendar={handleShowCalendar}
          onConfirmNoNosebleedsYesterday={handleConfirmNoNosebleedsYesterday}
          onConfirmYesterdayHadNosebleeds={handleConfirmYesterdayHadNosebleeds}
          onConfirmYesterdayDontRemember={handleConfirmYesterdayDontRemember}
          onShowMissingDataCalendar={handleShowMissingDataCalendar}
          onStartNoseStudyQuestionnaire={handleStartNoseStudyQuestionnaire}
          onStartQualityOfLifeSurvey={handleStartQualityOfLifeSurvey}
          onShowActiveQuestionnaire={handleShowActiveQuestionnaire}
          showNoNosebleedsButton={!hasEventsYesterday()}
          showMissingDataButton={shouldShowMissingDataButton()}
          showQuestionnaireButton={shouldShowQuestionnaireButton()}
          activeQuestionnaireName={activeQuestionnaire}
          incompleteRecords={getIncompleteRecords()}
          recordsWithOverlaps={getRecordsWithOverlaps()}
          demoMode={demoMode}
          onToggleDemoMode={toggleDemoMode}
          onResetAllData={handleResetAllData}
          onAddExampleData={handleAddExampleData}
          records={records}
          logoSrc={isEnrolledInTrial && enrollmentStatus === 'active' ? clinicalTrialLogo : cureHHTLogo}
          logoAlt={isEnrolledInTrial && enrollmentStatus === 'active' ? "Clinical Trial" : "CureHHT"}
          isSharingWithCureHHT={isSharingWithCureHHT}
          isEnrolledInTrial={isEnrolledInTrial}
          enrollmentStatus={enrollmentStatus}
          onEndClinicalTrialEnrollment={handleEndClinicalTrialEnrollment}
          onShowEnrollInTrial={handleStartClinicalTrialEnrollment}
        />
      </div>
      
      <CalendarOverlay
        isOpen={showCalendar}
        onClose={handleCloseCalendar}
        onDateSelect={handleDateSelect}
        selectedDate={selectedDate || new Date()}
        records={records}
        incompleteRecords={getIncompleteRecords()}
        missingDays={getMissingDataDays()}
      />
      <MissingDataCalendar
        isOpen={showMissingDataCalendar}
        onClose={handleCloseMissingDataCalendar}
        onDateSelect={handleMissingDateSelect}
        missingDays={getMissingDataDays()}
        records={records}
        incompleteRecords={getIncompleteRecords()}
      />
    </div>
  );
}