import React, { useState } from 'react';
import { motion } from 'motion/react';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Checkbox } from './ui/checkbox';
import { Dialog, DialogContent, DialogTitle, DialogDescription } from './ui/dialog';
import { ArrowLeft, Check, CheckCircle2 } from 'lucide-react';

interface ClinicalTrialEnrollmentProps {
  onBack: () => void;
  onEnroll: (enrollmentCode: string) => void;
}

export function ClinicalTrialEnrollment({ onBack, onEnroll }: ClinicalTrialEnrollmentProps) {
  const [code1, setCode1] = useState('');
  const [code2, setCode2] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [hasAgreedToSharing, setHasAgreedToSharing] = useState(false);
  const [shareDataPriorToEnrollment, setShareDataPriorToEnrollment] = useState(false);
  const [showEnrollmentDialog, setShowEnrollmentDialog] = useState(false);
  const [enrollmentSuccess, setEnrollmentSuccess] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    const fullCode = code1 + code2;
    
    // Basic validation - check if we have 10 characters total and agreement is checked
    if (fullCode.length !== 10 || !hasAgreedToSharing) {
      return;
    }
    
    setIsSubmitting(true);
    setShowEnrollmentDialog(true);
    setEnrollmentSuccess(false);
    
    // Show pending state for 3 seconds, then show success
    setTimeout(() => {
      setEnrollmentSuccess(true);
      
      // After showing success for 2 seconds, complete enrollment
      setTimeout(() => {
        onEnroll(fullCode);
        setIsSubmitting(false);
        setShowEnrollmentDialog(false);
      }, 2000);
    }, 3000);
  };

  const handleCode1Change = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value.replace(/[^a-zA-Z0-9]/g, '').toUpperCase().slice(0, 5);
    setCode1(value);
    
    // Auto-focus next field when this one is complete
    if (value.length === 5) {
      const nextInput = document.getElementById('code2');
      nextInput?.focus();
    }
  };

  const handleCode2Change = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value.replace(/[^a-zA-Z0-9]/g, '').toUpperCase().slice(0, 5);
    setCode2(value);
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>, field: 'code1' | 'code2') => {
    // Handle backspace to move to previous field
    if (e.key === 'Backspace' && field === 'code2' && code2 === '') {
      const prevInput = document.getElementById('code1');
      prevInput?.focus();
    }
  };

  const isComplete = code1.length === 5 && code2.length === 5 && hasAgreedToSharing;

  return (
    <div className="min-h-screen flex flex-col bg-background">
      {/* Header */}
      <div className="flex-none p-6">
        <div className="flex items-center gap-4 mb-6">
          <button 
            onClick={onBack}
            className="p-2 hover:bg-muted rounded-lg transition-colors"
            disabled={isSubmitting}
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <h1>Clinical Trial Enrollment</h1>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 flex flex-col justify-center p-6">
        <div className="max-w-sm mx-auto w-full space-y-6">
          <div className="text-center space-y-2">
            <h2>Enter Enrollment Code</h2>
            <p className="text-muted-foreground">
              Please enter the 10-digit enrollment code provided by your research coordinator.
            </p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="space-y-4">
              <div className="flex gap-3 justify-center">
                <div className="flex-1">
                  <Input
                    id="code1"
                    type="text"
                    value={code1}
                    onChange={handleCode1Change}
                    onKeyDown={(e) => handleKeyDown(e, 'code1')}
                    placeholder="XXXXX"
                    className="text-center text-lg tracking-wider font-mono"
                    maxLength={5}
                    disabled={isSubmitting}
                    autoComplete="off"
                    autoCapitalize="characters"
                  />
                </div>
                <div className="flex items-center">
                  <span className="text-muted-foreground">-</span>
                </div>
                <div className="flex-1">
                  <Input
                    id="code2"
                    type="text"
                    value={code2}
                    onChange={handleCode2Change}
                    onKeyDown={(e) => handleKeyDown(e, 'code2')}
                    placeholder="XXXXX"
                    className="text-center text-lg tracking-wider font-mono"
                    maxLength={5}
                    disabled={isSubmitting}
                    autoComplete="off"
                    autoCapitalize="characters"
                  />
                </div>
              </div>
              
              <div className="text-center">
                <small className="text-muted-foreground">
                  Code format: XXXXX-XXXXX (letters and numbers)
                </small>
              </div>
            </div>

            {/* Sharing Agreement Checkbox */}
            <div className="space-y-3">
              <div className="flex flex-col gap-3 p-4 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg">
                <div className="flex items-start gap-3">
                  <Checkbox
                    id="share-prior-data"
                    checked={shareDataPriorToEnrollment}
                    onCheckedChange={(checked) => setShareDataPriorToEnrollment(checked === true)}
                    disabled={isSubmitting}
                    className="mt-0.5"
                  />
                  <label
                    htmlFor="share-prior-data"
                    className="text-sm text-blue-800 dark:text-blue-200 cursor-pointer leading-relaxed"
                  >
                    Share data prior to enrollment (optional)
                  </label>
                </div>
                <div className="flex items-start gap-3">
                  <Checkbox
                    id="sharing-agreement"
                    checked={hasAgreedToSharing}
                    onCheckedChange={(checked) => setHasAgreedToSharing(checked === true)}
                    disabled={isSubmitting}
                    className="mt-0.5"
                  />
                  <label
                    htmlFor="sharing-agreement"
                    className="text-sm text-blue-800 dark:text-blue-200 cursor-pointer leading-relaxed"
                  >
                    I have read, understand, and consent to the sharing agreement for this clinical trial
                  </label>
                </div>
              </div>
            </div>

            <Button
              type="submit"
              className="w-full"
              size="lg"
              disabled={!isComplete || isSubmitting}
            >
              {isSubmitting ? (
                <div className="flex items-center gap-2">
                  <div className="w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />
                  Enrolling...
                </div>
              ) : (
                <div className="flex items-center gap-2">
                  <Check className="w-4 h-4" />
                  Enroll in Clinical Trial
                </div>
              )}
            </Button>
          </form>

        </div>
      </div>

      {/* Enrollment Dialog */}
      <Dialog open={showEnrollmentDialog} onOpenChange={setShowEnrollmentDialog}>
        <DialogContent className="sm:max-w-[425px]">
          <div className="flex flex-col space-y-6 py-4">
            <div className="flex items-center justify-center">
              {enrollmentSuccess ? (
                <motion.div
                  initial={{ scale: 0 }}
                  animate={{ scale: 1 }}
                  transition={{ 
                    type: "spring",
                    stiffness: 260,
                    damping: 20 
                  }}
                >
                  <CheckCircle2 className="w-16 h-16 text-green-500" />
                </motion.div>
              ) : (
                <div className="w-16 h-16 border-4 border-primary border-t-transparent rounded-full animate-spin" />
              )}
            </div>
            <motion.div
              key={enrollmentSuccess ? 'success' : 'pending'}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.3 }}
              className="space-y-2"
            >
              <DialogTitle className="text-center">
                {enrollmentSuccess ? 'Successfully Enrolled into a Study' : 'Pending Enrollment'}
              </DialogTitle>
              <DialogDescription className="text-center">
                {enrollmentSuccess 
                  ? 'You have been successfully enrolled in the clinical trial.' 
                  : 'Please wait while we process your enrollment...'}
              </DialogDescription>
            </motion.div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}