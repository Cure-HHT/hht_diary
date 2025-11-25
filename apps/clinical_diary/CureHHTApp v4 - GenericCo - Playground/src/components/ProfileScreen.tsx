import React, { useState } from 'react';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { ArrowLeft, User, FileText, Check, Users, Settings, Share, Edit } from 'lucide-react';
import cureHHTLogo from 'figma:asset/ba09a9637ac0ff172dab598ce95c889db4cb245f.png';
import clinicalTrialLogo from 'figma:asset/4884d92ca92ef779f1cec2253216537f9b341e00.png';

interface ProfileScreenProps {
  onBack: () => void;
  onStartClinicalTrialEnrollment: () => void;
  onShowSettings: () => void;
  onShareWithCureHHT: () => void;
  onStopSharingWithCureHHT: () => void;
  isEnrolledInTrial: boolean;
  enrollmentCode?: string | null;
  enrollmentDateTime?: Date | null;
  enrollmentEndDateTime?: Date | null;
  enrollmentStatus?: 'active' | 'ended';
  isSharingWithCureHHT: boolean;
  userName: string;
  onUpdateUserName: (name: string) => void;
}

export function ProfileScreen({ 
  onBack, 
  onStartClinicalTrialEnrollment, 
  onShowSettings,
  onShareWithCureHHT,
  onStopSharingWithCureHHT,
  isEnrolledInTrial, 
  enrollmentCode,
  enrollmentDateTime,
  enrollmentEndDateTime,
  enrollmentStatus = 'active',
  isSharingWithCureHHT,
  userName,
  onUpdateUserName
}: ProfileScreenProps) {
  const [isEditingName, setIsEditingName] = useState(false);
  const [tempName, setTempName] = useState(userName);

  const handleStartEditing = () => {
    setTempName(userName);
    setIsEditingName(true);
  };

  const handleCancelEditing = () => {
    setTempName(userName);
    setIsEditingName(false);
  };

  const handleSaveName = () => {
    const trimmedName = tempName.trim();
    if (trimmedName) {
      onUpdateUserName(trimmedName);
    } else {
      setTempName(userName); // Reset to original if empty
    }
    setIsEditingName(false);
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSaveName();
    } else if (e.key === 'Escape') {
      handleCancelEditing();
    }
  };

  return (
    <div className="min-h-screen flex flex-col bg-background">
      {/* Header */}
      <div className="flex-none p-6 pb-2">
        <div className="flex items-center gap-4 mb-4">
          <button 
            onClick={onBack}
            className="p-2 hover:bg-muted rounded-lg transition-colors"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <h1>User Profile</h1>
        </div>
        
        {/* CureHHT Logo */}
        <div className="flex justify-center mb-2">
          <img 
            src={cureHHTLogo} 
            alt="CureHHT" 
            className="h-12 sm:h-16"
          />
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 p-6 pt-2">
        <div className="max-w-md mx-auto space-y-6">
          
          {/* User Info Section */}
          <div className="space-y-4">
            <div className="flex items-center gap-3">
              <User className="w-5 h-5 text-muted-foreground" />
              <div>
                {isEditingName ? (
                  <div className="flex items-center gap-2">
                    <Input
                      value={tempName}
                      onChange={(e) => setTempName(e.target.value)}
                      onKeyDown={handleKeyPress}
                      onBlur={handleSaveName}
                      className="flex-1"
                      autoFocus
                      placeholder="Enter your name"
                    />
                    <Button
                      onClick={handleCancelEditing}
                      variant="ghost"
                      size="sm"
                      className="px-2"
                    >
                      Cancel
                    </Button>
                  </div>
                ) : (
                  <div className="flex items-center gap-2">
                    <h3 className="flex-1">{userName}</h3>
                    <Button
                      onClick={handleStartEditing}
                      variant="ghost"
                      size="sm"
                      className="px-2"
                    >
                      <Edit className="w-4 h-4" />
                    </Button>
                  </div>
                )}

              </div>
            </div>
          </div>

          {/* Settings Section */}
          <div>
            <Button
              onClick={onShowSettings}
              className="w-full"
              variant="outline"
            >
              <Settings className="w-4 h-4 mr-2" />
              Accessibility and Preferences
            </Button>
          </div>

          {/* Data Sharing Section */}
          <div>
            {isSharingWithCureHHT ? (
              <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
                <div className="flex items-start gap-3">
                  <div className="w-8 h-8 bg-blue-100 dark:bg-blue-900/40 rounded-full flex items-center justify-center flex-shrink-0">
                    <Check className="w-4 h-4 text-blue-600 dark:text-blue-400" />
                  </div>
                  <div className="space-y-3 flex-1">
                    <p className="font-medium text-blue-800 dark:text-blue-200">
                      Sharing with CureHHT
                    </p>
                    <Button
                      onClick={onStopSharingWithCureHHT}
                      className="w-full"
                      variant="outline"
                    >
                      <Share className="w-4 h-4 mr-2" />
                      Stop Sharing with CureHHT
                    </Button>
                  </div>
                </div>
              </div>
            ) : (
              <Button
                onClick={onShareWithCureHHT}
                className="w-full"
                variant="outline"
              >
                <Share className="w-4 h-4 mr-2" />
                Share with CureHHT
              </Button>
            )}
          </div>

          {/* Privacy & Data Protection */}
          <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
            <h4 className="font-medium text-blue-800 dark:text-blue-200 mb-2">
              Privacy & Data Protection
            </h4>
            <p className="text-sm text-blue-700 dark:text-blue-300">
              Your health data is stored locally on your device.
              {isSharingWithCureHHT && " Anonymized data is shared with CureHHT for research purposes."}
              {isEnrolledInTrial && enrollmentStatus === 'active' && " Clinical trial participation involves sharing anonymized data with researchers according to the study protocol."}
              {isEnrolledInTrial && enrollmentStatus === 'ended' && enrollmentEndDateTime && ` Clinical trial participation ended on ${enrollmentEndDateTime.toLocaleDateString()}. Previously shared data remains with researchers indefinitely for scientific analysis.`}
              {!isSharingWithCureHHT && !isEnrolledInTrial && " No data is shared with external parties unless you choose to participate in research or clinical trials."}
            </p>
          </div>

          {/* Clinical Trial Section */}
          <div className="space-y-4">
            <h3 className="flex items-center gap-2">
              <Users className="w-5 h-5" />
              Clinical Trial
            </h3>
            
            {isEnrolledInTrial ? (
              <div className="space-y-3">
                {enrollmentStatus === 'active' ? (
                  <div className="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-4">
                    <div className="flex items-center justify-center mb-3">
                      <img 
                        src={clinicalTrialLogo} 
                        alt="Terremoto" 
                        className="h-4 sm:h-5 lg:h-7 opacity-75"
                      />
                    </div>
                    <div className="flex items-start gap-3">
                      <div className="w-8 h-8 bg-green-100 dark:bg-green-900/40 rounded-full flex items-center justify-center flex-shrink-0">
                        <Check className="w-4 h-4 text-green-600 dark:text-green-400" />
                      </div>
                      <div className="space-y-2">
                        <p className="font-medium text-green-800 dark:text-green-200">
                          Enrolled in Clinical Trial
                        </p>
                        {enrollmentCode && (
                          <div className="text-xs text-green-600 dark:text-green-400 font-mono">
                            Enrollment Code: {enrollmentCode.slice(0, 5)}-{enrollmentCode.slice(5)}
                          </div>
                        )}
                        {enrollmentDateTime && (
                          <div className="text-xs text-green-600 dark:text-green-400">
                            Enrolled: {enrollmentDateTime.toLocaleDateString()} at {enrollmentDateTime.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit', hour12: true })}
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                ) : (
                  <div className="bg-gray-50 dark:bg-gray-900/20 border border-gray-200 dark:border-gray-800 rounded-lg p-4">
                    <div className="flex items-center justify-center mb-3">
                      <img 
                        src={clinicalTrialLogo} 
                        alt="Terremoto" 
                        className="h-4 sm:h-5 lg:h-7 opacity-75"
                      />
                    </div>
                    <div className="flex items-start gap-3">
                      <div className="w-8 h-8 bg-gray-100 dark:bg-gray-900/40 rounded-full flex items-center justify-center flex-shrink-0">
                        <Check className="w-4 h-4 text-gray-600 dark:text-gray-400" />
                      </div>
                      <div className="space-y-2">
                        <p className="font-medium text-gray-800 dark:text-gray-200">
                          Clinical Trial Enrollment: Ended
                        </p>
                        {enrollmentCode && (
                          <div className="text-xs text-gray-600 dark:text-gray-400 font-mono">
                            Enrollment Code: {enrollmentCode.slice(0, 5)}-{enrollmentCode.slice(5)}
                          </div>
                        )}
                        {enrollmentDateTime && (
                          <div className="text-xs text-gray-600 dark:text-gray-400">
                            Enrolled: {enrollmentDateTime.toLocaleDateString()} at {enrollmentDateTime.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit', hour12: true })}
                          </div>
                        )}
                        {enrollmentEndDateTime && (
                          <div className="text-xs text-gray-600 dark:text-gray-400">
                            Ended: {enrollmentEndDateTime.toLocaleDateString()} at {enrollmentEndDateTime.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit', hour12: true })}
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                )}
                <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-3">
                  <p className="text-xs text-blue-700 dark:text-blue-300">
                    {enrollmentStatus === 'active' 
                      ? "Note: The logo displayed on the homescreen of the app is a reminder that you are sharing your data with a 3rd party."
                      : "Note: Data shared during clinical trial participation remains with researchers indefinitely for scientific analysis."
                    }
                  </p>
                </div>
              </div>
            ) : (
              <Button
                onClick={onStartClinicalTrialEnrollment}
                className="w-full"
                variant="outline"
              >
                <FileText className="w-4 h-4 mr-2" />
                Enroll in Clinical Trial
              </Button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}