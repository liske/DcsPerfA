SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




/****** Object:  View [dbo].[CounterDefs]    Script Date: 21.02.2013 14:38:39 ******/
CREATE VIEW [dbo].[CounterDefs] AS
	SELECT
		p.ObjectId,
		cd.CounterIndex,
		sd.TypeName,
		p.Identifiable_Caption,
		p.Identifiable_ExtendedCaption,
		cd.Name,
		cd.CounterType,
		cd.MeasurementUnit

	FROM [DcsPerf].[dbo].SampleDefinition sd
	JOIN [DcsPerf].[dbo].CounterDefinition cd ON sd.SampleType = cd.SampleType
	JOIN [DcsPerf].[dbo].PerformanceInstance p ON cd.SampleType = p.SampleType

GO




/****** Object:  View [dbo].[CounterData]    Script Date: 21.02.2013 14:41:55 ******/
CREATE VIEW [dbo].[CounterData] AS
	SELECT
		s.SampleTime,
		p.ObjectId,
		c.CounterIndex,
		c.Data
	FROM [DcsPerf].[dbo].Counter c
		JOIN [DcsPerf].[dbo].Sample s
		ON c.SampleId = s.SampleId
		JOIN [DcsPerf].[dbo].PerformanceInstance p
		ON s.ObjectId = p.ObjectId


GO
