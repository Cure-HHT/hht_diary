import React, { useState } from 'react';
import { Button } from './ui/button';
import { Card, CardContent } from './ui/card';
import { RadioGroup, RadioGroupItem } from './ui/radio-group';
import { Label } from './ui/label';
import { Progress } from './ui/progress';
import { ArrowLeft, ArrowRight, Check } from 'lucide-react';

export interface PreambleItem {
  id: string;
  content: string;
}

export interface QuestionItem {
  id: string;
  question: string | React.ReactNode;
  options: string[];
  required?: boolean;
}

export interface QuestionnaireData {
  name: string;
  preamble: PreambleItem[];
  questions: QuestionItem[];
}

interface QuestionnaireFlowProps {
  questionnaire: QuestionnaireData;
  onComplete: (responses: Record<string, string>) => void;
  onCancel?: () => void;
}

type FlowStep = 'preamble' | 'questions' | 'summary';

export function QuestionnaireFlow({ questionnaire, onComplete, onCancel }: QuestionnaireFlowProps) {
  const [currentStep, setCurrentStep] = useState<FlowStep>('preamble');
  const [preambleIndex, setPreambleIndex] = useState(0);
  const [questionIndex, setQuestionIndex] = useState(0);
  const [responses, setResponses] = useState<Record<string, string>>({});

  const currentPreambleItem = questionnaire.preamble[preambleIndex];
  const currentQuestion = questionnaire.questions[questionIndex];

  // Helper function to parse question text into instruction and specific question
  const parseQuestion = (questionText: string | React.ReactNode) => {
    // If it's JSX, don't parse - just return the whole thing as instruction
    if (typeof questionText !== 'string') {
      return {
        instruction: questionText,
        specificQuestion: null
      };
    }
    
    // Split on the pattern: instruction with "your nosebleeds:" or "your nosebleeds?" followed by specific item
    const colonMatch = questionText.match(/^(.+?your nosebleeds:)\s*(.+)$/);
    const questionMatch = questionText.match(/^(.+?your nosebleeds\?)\s*(.+)$/);
    
    if (colonMatch) {
      return {
        instruction: colonMatch[1],
        specificQuestion: colonMatch[2]
      };
    } else if (questionMatch) {
      return {
        instruction: questionMatch[1],
        specificQuestion: questionMatch[2]
      };
    }
    
    // Fallback: treat entire question as instruction if no pattern matches
    return {
      instruction: questionText,
      specificQuestion: null
    };
  };

  const parsedQuestion = currentQuestion ? parseQuestion(currentQuestion.question) : null;
  
  const totalSteps = questionnaire.preamble.length + questionnaire.questions.length + 1; // +1 for summary
  const currentStepNumber = currentStep === 'preamble' 
    ? preambleIndex + 1 
    : currentStep === 'questions'
    ? questionnaire.preamble.length + questionIndex + 1
    : totalSteps; // summary step is the last step

  const handlePreambleNext = () => {
    if (preambleIndex < questionnaire.preamble.length - 1) {
      setPreambleIndex(preambleIndex + 1);
    } else {
      setCurrentStep('questions');
    }
  };

  const handleQuestionNext = () => {
    if (questionIndex < questionnaire.questions.length - 1) {
      setQuestionIndex(questionIndex + 1);
    } else {
      // Go to summary screen
      setCurrentStep('summary');
    }
  };

  const handleQuestionBack = () => {
    if (questionIndex > 0) {
      setQuestionIndex(questionIndex - 1);
    } else {
      setCurrentStep('preamble');
      setPreambleIndex(questionnaire.preamble.length - 1);
    }
  };

  const handleSummaryBack = () => {
    setCurrentStep('questions');
    setQuestionIndex(questionnaire.questions.length - 1);
  };

  const handleEditQuestion = (questionId: string) => {
    const questionIndex = questionnaire.questions.findIndex(q => q.id === questionId);
    if (questionIndex !== -1) {
      setQuestionIndex(questionIndex);
      setCurrentStep('questions');
    }
  };

  const handleCompleteFromSummary = () => {
    onComplete(responses);
  };

  const handleResponseChange = (questionId: string, value: string) => {
    setResponses(prev => ({
      ...prev,
      [questionId]: value
    }));
  };

  const isCurrentQuestionAnswered = currentQuestion && responses[currentQuestion.id];
  const isLastQuestion = questionIndex === questionnaire.questions.length - 1;
  const canProceed = currentStep === 'preamble' || isCurrentQuestionAnswered;
  const hasStartedAnswering = Object.keys(responses).length > 0;
  const canCancel = currentStep === 'preamble' && preambleIndex === 0 && !hasStartedAnswering;
  const allQuestionsAnswered = questionnaire.questions.every(q => responses[q.id]);

  return (
    <div className="min-h-screen flex flex-col bg-background">
      {/* Header */}
      <div className="flex-none p-6 md:p-4">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-3">
            {onCancel && canCancel && (
              <Button
                variant="ghost"
                size="sm"
                onClick={onCancel}
                className="p-2"
              >
                <ArrowLeft className="w-4 h-4" />
              </Button>
            )}
            <h1 className="text-lg font-medium">{questionnaire.name}</h1>
          </div>
        </div>
        
        {/* Progress */}
        <div className="space-y-2">
          <div className="flex items-center justify-between text-sm text-muted-foreground">
            <span>
              {currentStep === 'preamble' ? 'Reading Instructions' : 
               currentStep === 'questions' ? 'Questions' : 'Review Answers'}
            </span>
            <span>{currentStepNumber} of {totalSteps}</span>
          </div>
          <Progress 
            value={(currentStepNumber / totalSteps) * 100} 
            className="h-2"
          />
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 flex flex-col justify-center p-6 md:p-4">
        <Card className="w-full max-w-2xl mx-auto">
          {currentStep === 'preamble' ? (
            <CardContent className="p-6 md:p-8">
              <div className="space-y-6">
                <div className="text-foreground leading-relaxed text-center space-y-4">
                  {currentPreambleItem.content.split('\n\n').map((part, index) => (
                    <p key={index} className={index === 0 ? 'font-bold' : ''}>
                      {part}
                    </p>
                  ))}
                </div>
                
                <div className="flex justify-center pt-4">
                  <Button 
                    onClick={handlePreambleNext}
                    className="px-8"
                  >
                    {preambleIndex === questionnaire.preamble.length - 1 ? 'Begin Questions' : 'Okay'}
                    <ArrowRight className="w-4 h-4 ml-2" />
                  </Button>
                </div>
              </div>
            </CardContent>
          ) : currentStep === 'questions' ? (
            <CardContent className="p-6 md:p-8">
              <div className="space-y-6">
                <div className="space-y-4">
                  {/* Time period context */}
                  <div className="text-sm text-muted-foreground mb-3">
                    {questionnaire.name === 'Quality of Life Survey' ? 'Over the past 4 weeks' : 'Over the past two weeks'}
                  </div>
                  
                  {/* Instruction */}
                  {parsedQuestion?.instruction && (
                    <div className="text-foreground leading-relaxed mb-3">
                      {parsedQuestion.instruction}
                    </div>
                  )}
                  
                  {/* Specific question */}
                  {parsedQuestion?.specificQuestion && (
                    <div className="text-foreground leading-relaxed font-medium">
                      {parsedQuestion.specificQuestion}
                    </div>
                  )}
                  
                  {/* Fallback for unparsed questions */}
                  {!parsedQuestion?.instruction && (
                    <div className="text-foreground leading-relaxed">
                      {currentQuestion.question}
                    </div>
                  )}
                  
                  <RadioGroup
                    value={responses[currentQuestion.id] || ''}
                    onValueChange={(value) => handleResponseChange(currentQuestion.id, value)}
                    className="space-y-2"
                  >
                    {currentQuestion.options.map((option, index) => (
                      <div key={index} className="flex items-center space-x-3">
                        <RadioGroupItem 
                          value={option} 
                          id={`${currentQuestion.id}-${index}`}
                        />
                        <Label 
                          htmlFor={`${currentQuestion.id}-${index}`}
                          className="flex-1 cursor-pointer"
                        >
                          {option}
                        </Label>
                      </div>
                    ))}
                  </RadioGroup>
                </div>
                
                <div className="flex justify-between pt-4">
                  <Button 
                    variant="outline"
                    onClick={handleQuestionBack}
                  >
                    <ArrowLeft className="w-4 h-4 mr-2" />
                    Back
                  </Button>
                  
                  <Button 
                    onClick={handleQuestionNext}
                    disabled={!canProceed}
                  >
                    {isLastQuestion ? (
                      <>
                        Review Answers
                        <ArrowRight className="w-4 h-4 ml-2" />
                      </>
                    ) : (
                      <>
                        Next
                        <ArrowRight className="w-4 h-4 ml-2" />
                      </>
                    )}
                  </Button>
                </div>
              </div>
            </CardContent>
          ) : (
            <CardContent className="p-6 md:p-8">
              <div className="space-y-6">
                <div className="text-center mb-6">
                  <h2 className="text-lg font-medium mb-2">Review Your Answers</h2>
                  <p className="text-sm text-muted-foreground">
                    Review your responses below. Tap any answer to make changes.
                  </p>
                </div>

                <div className="space-y-4 max-h-96 overflow-y-auto">
                  {questionnaire.questions.map((question, index) => {
                    const parsed = parseQuestion(question.question);
                    const answer = responses[question.id];
                    
                    return (
                      <div key={question.id} className="border border-border rounded-lg p-4">
                        <div className="space-y-2">
                          <div className="text-sm text-muted-foreground">
                            Question {index + 1}
                          </div>
                          <div className="text-sm leading-relaxed">
                            {parsed.specificQuestion || parsed.instruction}
                          </div>
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => handleEditQuestion(question.id)}
                            className="w-full justify-start text-left mt-2"
                          >
                            <span className="font-medium text-primary">
                              {answer || 'No answer selected'}
                            </span>
                          </Button>
                        </div>
                      </div>
                    );
                  })}
                </div>

                <div className="flex justify-between pt-4">
                  <Button 
                    variant="outline"
                    onClick={handleSummaryBack}
                  >
                    <ArrowLeft className="w-4 h-4 mr-2" />
                    Back to Questions
                  </Button>
                  
                  <Button 
                    onClick={handleCompleteFromSummary}
                    disabled={!allQuestionsAnswered}
                    className="bg-green-600 hover:bg-green-700"
                  >
                    Submit Survey
                    <Check className="w-4 h-4 ml-2" />
                  </Button>
                </div>
              </div>
            </CardContent>
          )}
        </Card>
      </div>
    </div>
  );
}