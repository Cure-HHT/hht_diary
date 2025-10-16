// TODO: in the original mock-up, all events (epistaxis and survey) were stored in the same structure, with optional fields being used depending on the type.
// TODO: in this mock-up, there is a proposed hierarchy. The final design should accomodate the schema-versioning system already architected.

// IMPORTANT: for long-term auditabilty, it is recommended to make data clear and unambigious even without the context of its database system. So the data should not, for example, use a number 1-6 as an enumerated type. Instead it should use meaningful strings for each enum, with validation to ensure consistency


export type EventRecord = {
  id: string;                         // v7 UUID per RFC 9562  startTime?: Date;                   
  versioned_type: string;             // epistaxis records or survey, and which version number
  event_data: string;                 // a record of type EpistaxisRecord or SurveyRecord
}

export type EpistaxisRecord = {
  id: string;                         // TODO: same as parent id?                   
  startTime: Date;                    // ISO 8601 : YYYY-MM-DDTHH:MM:SS±HH:MM
  endTime?: Date;                     // ISO 8601 : YYYY-MM-DDTHH:MM:SS±HH:MM
  severity?: string;                  // one of six values from a pre-defined list
  user_notes?: string;                // notes entered by the user pertaining to this record
  isNoNosebleedsEvent?: boolean;      // true iff user confirmed that there were no nosebleeds on startTime's day. 
  isUnknownNosebleedsEvent?: boolean; // true iff user confirmed that they don't recall that day's nosebleed events
  isIncomplete?: boolean;             // true iff the record has been partially completed (e.g. startTime only)
  lastModified: Date;
};

// TODO: survey should be a structure of question/resposes rather than a flat string 
export type SurveyRecord = {
  id: string;                         // TODO: same as parent id?
  survey?: string;                    // set of complete question and response (if any) pairs
  score?: string;                     // score according to rubric per versione_type
};
