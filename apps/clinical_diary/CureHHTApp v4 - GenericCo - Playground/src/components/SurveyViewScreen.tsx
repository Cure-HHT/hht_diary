import React from 'react';
import { Button } from './ui/button';
import { Card, CardContent } from './ui/card';
import { ArrowLeft, FileText } from 'lucide-react';
import { QuestionnaireData } from './QuestionnaireFlow';
import { QuestionnaireResponse } from '../data/questionnaires';

interface SurveyViewScreenProps {
  questionnaire: QuestionnaireData;
  response: QuestionnaireResponse;
  onBack: () => void;
}

export function SurveyViewScreen({ questionnaire, response, onBack }: SurveyViewScreenProps) {
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
          <div className="flex items-center gap-2">
            <FileText className="w-5 h-5 text-muted-foreground" />
            <h1>Survey Results</h1>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 p-6 pt-2">
        <div className="max-w-md mx-auto space-y-6">
          {/* Survey Header */}
          <div className="text-center space-y-2">
            <h2>{questionnaire.name}</h2>
            <p className="text-sm text-muted-foreground">
              Completed on {response.completedAt.toLocaleDateString()} at {response.completedAt.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit', hour12: true })}
            </p>
          </div>

          {/* Questions and Responses */}
          <div className="space-y-4">
            {questionnaire.questions.map((question, index) => {
              const responseValue = response.responses[question.id];
              
              return (
                <Card key={question.id} className="border border-muted">
                  <CardContent className="p-4">
                    <div className="space-y-3">
                      <div className="text-sm text-muted-foreground">
                        Question {index + 1}
                      </div>
                      
                      <div className="space-y-2">
                        <p className="text-sm leading-relaxed">
                          {typeof question.question === 'string' ? question.question : question.question}
                        </p>
                      </div>
                      
                      <div className="pt-2 border-t border-muted">
                        <div className="text-sm text-muted-foreground mb-1">
                          Your Response:
                        </div>
                        <div className="p-3 bg-muted/50 rounded-lg">
                          <p className="text-sm font-medium">
                            {responseValue || 'No response recorded'}
                          </p>
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>

          {/* Summary */}
          <Card className="border border-muted bg-muted/20">
            <CardContent className="p-4">
              <div className="text-center space-y-2">
                <h4 className="text-sm font-medium text-muted-foreground">
                  Survey Summary
                </h4>
                <p className="text-xs text-muted-foreground">
                  {questionnaire.questions.length} questions completed
                </p>
                <p className="text-xs text-muted-foreground">
                  This is a view-only display of your completed survey responses
                </p>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}